#include <iostream>
#include <thread>
#include <vector>
#include <mutex>
#include <chrono>


std::mutex hot_mutex;
std::mutex cold_mutex;


void hot_function() {
    for (int i = 0; i < 100000; i++) {
        std::lock_guard<std::mutex> lock(hot_mutex);
        std::this_thread::sleep_for(std::chrono::microseconds(50));
    }
}


void cold_function() {
    for (int i = 0; i < 100000; i++) {
        std::lock_guard<std::mutex> lock(cold_mutex);
        std::this_thread::sleep_for(std::chrono::microseconds(5));
    }
}


int main() {
    std::cout << "hot_mutex: " << &hot_mutex << std::endl;
    std::cout << "cold_mutex: " << &cold_mutex << std::endl;

    std::vector<std::thread> threads;


    for (int i = 0; i < 8; i++)
        threads.emplace_back(hot_function);


    for (int i = 0; i < 2; i++)
        threads.emplace_back(cold_function);


    for (auto &t : threads)
        t.join();


    return 0;
}
