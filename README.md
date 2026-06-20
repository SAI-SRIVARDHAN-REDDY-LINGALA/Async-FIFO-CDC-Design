# Async-FIFO-CDC-Design
Modular, parameterized asynchronous FIFO in Verilog for safe cross-clock-domain data transfer. Uses dual binary/Gray-code pointers, two-flop synchronizers, and pessimistic full/empty detection per Cummings' CDC methodology. Verified with two testbenches covering reset, overflow/underflow, and randomized traffic.
