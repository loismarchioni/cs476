rm -f profileCi_tb
iverilog -s tb_profcounters -o profileCi_tb ../verilog/counter.v ../verilog/profileCi.v ../verilog/profileCi_tb.v
vvp profileCi_tb
gtkwave waveform.vcd waveform.gtkw