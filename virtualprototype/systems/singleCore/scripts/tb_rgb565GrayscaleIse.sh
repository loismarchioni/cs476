rm -f tb_rgb565GrayscaleIse
iverilog -s tb_rgb565GrayscaleIse -o tb_rgb565GrayscaleIse ../verilog/rgb565GrayscaleIse.v ../verilog/tb_rgb565GrayscaleIse.v
vvp tb_rgb565GrayscaleIse
gtkwave rgb565GrayscaleIse.vcd rgb565GrayscaleIse.gtkw