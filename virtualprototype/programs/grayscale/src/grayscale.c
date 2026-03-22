#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>


int main () {
  static volatile uint16_t rgb565[640*480];
  static volatile uint8_t grayscale[640*480];
  volatile uint32_t result, cycles,stall,idle;
  volatile unsigned int *vga = (unsigned int *) 0X50000020;
  camParameters camParams;
  vga_clear();
  
  printf("Initialising camera (this takes up to 3 seconds)!\n" );
  camParams = initOv7670(VGA);
  printf("Done!\n" );
  printf("NrOfPixels : %d\n", camParams.nrOfPixelsPerLine );
  result = (camParams.nrOfPixelsPerLine <= 320) ? camParams.nrOfPixelsPerLine | 0x80000000 : camParams.nrOfPixelsPerLine;
  vga[0] = swap_u32(result);
  printf("NrOfLines  : %d\n", camParams.nrOfLinesPerImage );
  result =  (camParams.nrOfLinesPerImage <= 240) ? camParams.nrOfLinesPerImage | 0x80000000 : camParams.nrOfLinesPerImage;
  vga[1] = swap_u32(result);
  printf("PCLK (kHz) : %d\n", camParams.pixelClockInkHz );
  printf("FPS        : %d\n", camParams.framesPerSecond );
  uint32_t * rgb = (uint32_t *) &rgb565[0];
  uint32_t grayPixels;
  vga[2] = swap_u32(2);
  vga[3] = swap_u32((uint32_t) &grayscale[0]);


  // counters control variables
  uint32_t reset_control   = 0xF00;   // bits[11:8] = 1   => valueB[11:8] = 1111
  uint32_t enable_control  = 0x7;     // bits[2:0] = 1    => valueB[2:0] = 111
  uint32_t disable_control = 0xF0;    // bits[7:4] = 1    => valueB[7:4] = 1111
  uint32_t counter_id      = 0;

  // grayscale conversion control
  uint8_t grayscale_mode = 1;       // 0: default conversion, 1: usign CI 
  uint32_t gray_out_ci;
  uint32_t pixel_in_ci;

  while(1) {

    // take image
    uint32_t * gray = (uint32_t *) &grayscale[0];
    takeSingleImageBlocking((uint32_t) &rgb565[0]);


    // Reset all counters first, then enable counter0 (CPU cycles), counter1 (stall), counter2 (bus-idle)
    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xB" :: [in2] "r" (reset_control));
    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xB" :: [in2] "r" (enable_control));

    // grayscale conversion : alternate between default implementation and custom instruction
    for (int line = 0; line < camParams.nrOfLinesPerImage; line++) {
      for (int pixel = 0; pixel < camParams.nrOfPixelsPerLine; pixel++) {

        switch(grayscale_mode){
          case 0:
            uint16_t rgb = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel]);
            uint32_t red1 = ((rgb >> 11) & 0x1F) << 3;
            uint32_t green1 = ((rgb >> 5) & 0x3F) << 2;
            uint32_t blue1 = (rgb & 0x1F) << 3;
            uint32_t gray = ((red1*54+green1*183+blue1*19) >> 8)&0xFF;
            grayscale[line*camParams.nrOfPixelsPerLine+pixel] = gray;

            break;

          case 1:
            pixel_in_ci = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel]);
            asm volatile ("l.nios_rrr %[out], %[in1], r0, 0x8" : [out] "=r" (gray_out_ci) : [in1] "r"  (pixel_in_ci));
            grayscale[line*camParams.nrOfPixelsPerLine+pixel] = gray_out_ci;

            break;
            
          default : break;
        }

      }
    }

    // Disable all counters before reading 
    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xB" :: [in2] "r" (disable_control));

    // Read counters : counter0 (CPU cycles), counter1 (stall cycles), counter2 (bus-idle cycles)
    counter_id = 0;
    asm volatile ("l.nios_rrr %[out1], %[in1], r0, 0xB" : [out1] "=r" (cycles) : [in1] "r" (counter_id));
    counter_id = 1;
    asm volatile ("l.nios_rrr %[out1], %[in1], r0, 0xB" : [out1] "=r" (stall) : [in1] "r" (counter_id));
    counter_id = 2;
    asm volatile ("l.nios_rrr %[out1], %[in1], r0, 0xB" : [out1] "=r" (idle) : [in1] "r" (counter_id));

    // Print results
    switch (grayscale_mode){
      case 0: printf("Grayscale conversion without the custom instruction.\n"); break;
      case 1: printf("Grayscale conversion using the custom instruction.\n"); break;
      default : break;
    }

    printf("Execution cycles:       %lu\n", cycles);
    printf("Real execution cycles:  %lu\n", cycles - stall);
    printf("Stall cycles:           %lu\n", stall);
    printf("Bus idle cycles:        %lu\n\n", idle);

    // swap grayscale mode
    grayscale_mode = (grayscale_mode == 0) ? 1 : 0;


  }
}
