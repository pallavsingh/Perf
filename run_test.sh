#!/bin/bash

set -e

APP_NAME="mutex_contention"
SRC_NAME="main.cc"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

MUTEX_TRACE_PID=""
CONTENTION_TRACE_PID=""
CANCELLED=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
}

cleanup() {
    echo ""
    echo "================================================="
    echo "  Cleaning Up"
    echo "================================================="

    if [ -n "${MUTEX_TRACE_PID}" ]; then
        kill "${MUTEX_TRACE_PID}" 2>/dev/null || true
        wait "${MUTEX_TRACE_PID}" 2>/dev/null || true
    fi

    if [ -n "${CONTENTION_TRACE_PID}" ]; then
        kill "${CONTENTION_TRACE_PID}" 2>/dev/null || true
        wait "${CONTENTION_TRACE_PID}" 2>/dev/null || true
    fi

    pass "BPF tracing stopped."

    if [ -f "${APP_NAME}" ]; then
        if rm -f "${APP_NAME}"; then
            pass "${APP_NAME} removed."
        else
            fail "Failed to remove ${APP_NAME}."
        fi
    fi
}

handle_exit() {
    EXIT_STATUS=$?

    cleanup

    if [ "${CANCELLED}" -eq 1 ]; then
        echo ""
        fail "Test cancelled by user."
    elif [ "${EXIT_STATUS}" -ne 0 ]; then
        echo ""
        fail "Test failed."
    else
        echo ""
        echo "================================================="
        pass "All tests completed successfully."
        echo "================================================="
    fi

    exit "${EXIT_STATUS}"
}

handle_signal() {
    CANCELLED=1
    exit 130
}

trap handle_exit EXIT
trap handle_signal INT TERM

echo "================================================="
echo "  1. Compiling Mutex Contention Test"
echo "================================================="

if g++ -g -O2 -std=c++20 -Wall "${SRC_NAME}" -o "${APP_NAME}" -pthread; then
    pass "Compilation successful."
else
    fail "Compilation failed."
    exit 1
fi

echo ""
echo "================================================="
echo "  2. Starting BPF Tracing"
echo "================================================="

echo "Starting mutex_trace.bt..."
sudo bpftrace mutex_trace.bt &
MUTEX_TRACE_PID=$!

echo "Starting contention_graph.bt..."
sudo bpftrace contention_graph.bt &
CONTENTION_TRACE_PID=$!

# Give bpftrace time to attach
sleep 1

if kill -0 "${MUTEX_TRACE_PID}" 2>/dev/null; then
    pass "mutex_trace.bt started."
else
    fail "mutex_trace.bt failed to start."
    exit 1
fi

if kill -0 "${CONTENTION_TRACE_PID}" 2>/dev/null; then
    pass "contention_graph.bt started."
else
    fail "contention_graph.bt failed to start."
    exit 1
fi

echo ""
echo "================================================="
echo "  3. Running Mutex Contention Test"
echo "================================================="

echo "Running ./${APP_NAME}..."
echo "-------------------------------------------------"

if ./"${APP_NAME}"; then
    pass "Mutex contention test completed successfully."
else
    fail "Mutex contention test failed."
    exit 1
fi
