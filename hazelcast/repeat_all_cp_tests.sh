#!/usr/bin/env bash

ssh-keyscan -t ssh-ed25519 n1 >> ~/.ssh/known_hosts
ssh-keyscan -t ssh-ed25519 n2 >> ~/.ssh/known_hosts
ssh-keyscan -t ssh-ed25519 n3 >> ~/.ssh/known_hosts
ssh-keyscan -t ssh-ed25519 n4 >> ~/.ssh/known_hosts
ssh-keyscan -t ssh-ed25519 n5 >> ~/.ssh/known_hosts

tests=("non-reentrant-lock" "reentrant-lock" "non-reentrant-fenced-lock" "reentrant-fenced-lock" "semaphore" "id-gen-long" "cas-long" "cas-reference" "cas-cp-map")

if [ $# -lt 3 ]; then
  echo "Usage: ./repeat_all_cp_tests.sh repeat test_duration license [tests...]"
  echo "Tests: ${tests[*]}"
  exit 1
fi

repeat=$1
test_duration=$2
license=$3

# If extra args are given, treat them as the list of tests to run
if [ $# -gt 3 ]; then
  tests=()
  for i in "${@:4}"; do
    tests+=("$i")
  done
fi

run_single_test () {
    test_name=$1
    nemesis=$2
    persistent=$3
    cp_direct_to_leader_routing=$4
    step_down=$5

    echo "Running '$test_name' test with '$nemesis' nemesis, persistent=$persistent, cp_direct_to_leader_routing=$cp_direct_to_leader_routing, step_down=$step_down"

    lein run test \
      --workload "${test_name}" \
      --time-limit "${test_duration}" \
      --license "${license}" \
      --nemesis "${nemesis}" \
      --persistent "${persistent}" \
      --cp-direct-to-leader-routing "${cp_direct_to_leader_routing}" \
      --step-down-when-leader "${step_down}"

    if [ $? != 0 ]; then
        echo "'$test_name' test failed"
        exit 1
    fi
}

round=1
echo "Will run [${tests[*]}] tests..."

while [ "${round}" -le "${repeat}" ]; do

    echo "round: $round"

    for test in "${tests[@]}"; do
      # partition, non-persistent
      run_single_test "${test}" "partition" "false" "false" "false"  # baseline
      run_single_test "${test}" "partition" "false" "false" "n1"    # abdicating leader (only n1)
      run_single_test "${test}" "partition" "false" "true"  "false" # direct routing, no abdication

      # partition, persistent
      run_single_test "${test}" "partition" "true"  "false" "false" # baseline
      run_single_test "${test}" "partition" "true"  "false" "n1"    # abdicating leader (only n1)

      # restart-majority, persistent
      run_single_test "${test}" "restart-majority" "true"  "false" "false" # baseline
      run_single_test "${test}" "restart-majority" "true"  "true"  "false" # direct routing, no abdication
      # restart-majority, non-persistent, abdicating leader
      run_single_test "${test}" "restart-majority" "false" "false" "n1"
    done

    ((round++))
done
