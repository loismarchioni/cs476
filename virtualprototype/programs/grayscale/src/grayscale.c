#include <stdio.h>
#include <ov7670.h>
#include <swap.h>
#include <vga.h>


int main () {
  volatile uint16_t rgb565[640*480];
  volatile uint8_t grayscale[640*480];
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
  while(1) {

    // Reset all counters first (valueB[11:8] = 1111)
    uint32_t reset_control = 0xF00; // bits[11:8] = 1
    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xB" :: [in2] "r" (reset_control));

    // Enable counter0 (CPU cycles), counter1 (stall), counter2 (bus-idle)
    // valueB[2:0] = 111
    uint32_t enable_control = 0x7; // bits[2:0] = 1
    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xB" :: [in2] "r" (enable_control));

    uint32_t * gray = (uint32_t *) &grayscale[0];
    takeSingleImageBlocking((uint32_t) &rgb565[0]);

    for (int line = 0; line < camParams.nrOfLinesPerImage; line++) {
      for (int pixel = 0; pixel < camParams.nrOfPixelsPerLine; pixel++) {
        uint16_t rgb = swap_u16(rgb565[line*camParams.nrOfPixelsPerLine+pixel]);
        uint32_t red1 = ((rgb >> 11) & 0x1F) << 3;
        uint32_t green1 = ((rgb >> 5) & 0x3F) << 2;
        uint32_t blue1 = (rgb & 0x1F) << 3;
        uint32_t gray = ((red1*54+green1*183+blue1*19) >> 8)&0xFF;
        grayscale[line*camParams.nrOfPixelsPerLine+pixel] = gray;
      }
    }
    
    // Disable all counters before reading (valueB[7:4] = 1111)
    uint32_t disable_control = 0xF0; // bits[7:4] = 1
    asm volatile ("l.nios_rrr r0, r0, %[in2], 0xB" :: [in2] "r" (disable_control));

    // Read counter0 (CPU cycles)
    uint32_t counter_id = 0;
    asm volatile ("l.nios_rrr %[out1], %[in1], r0, 0xB" : [out1] "=r" (cycles) : [in1] "r" (counter_id));

    // Read counter1 (stall cycles)
    counter_id = 1;
    asm volatile ("l.nios_rrr %[out1], %[in1], r0, 0xB" : [out1] "=r" (stall) : [in1] "r" (counter_id));

    // Read counter2 (bus-idle cycles)
    counter_id = 2;
    asm volatile ("l.nios_rrr %[out1], %[in1], r0, 0xB" : [out1] "=r" (idle) : [in1] "r" (counter_id));

    // Print results
    printf("Execution cycles: %lu\n", cycles);
    printf("Stall cycles:     %lu\n", stall);
    printf("Bus idle cycles:  %lu\n", idle);

  }
}
