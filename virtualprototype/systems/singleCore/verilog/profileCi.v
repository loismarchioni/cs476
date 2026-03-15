module profcounters #(
    parameter [7:0] customId = 8'h00
  )(
    input  wire        start,
    input  wire        clock,
    input  wire        reset,
    input  wire        stall,
    input  wire        busIdle,
    input  wire [31:0] valueA,
    input  wire [31:0] valueB,
    input  wire  [7:0] ciN,
    output wire        done,
    output wire [31:0] result
  );

reg [31:0] counterValue;
wire [31:0] counterValue0, counterValue1, counterValue2, counterValue3;

assign done   = (ciN == customId) & start;
assign result = ((ciN == customId) & start) ? counterValue : 32'b0;


reg enable0, enable1, enable2, enable3;

always @(posedge clock) begin
  if((ciN == customId) & start) begin
    enable0 <= valueB[0] & ~valueB[4];
    enable1 <= valueB[1] & ~valueB[5];
    enable2 <= valueB[2] & ~valueB[6];
    enable3 <= valueB[3] & ~valueB[7];
  end

  if(reset) begin
    {enable0, enable1, enable2, enable3} <= 0;   
  end  

end       


counter #(.WIDTH(32)) c0 (
  .reset  (reset | ((ciN == customId) & start & valueB[8])),
  .clock  (clock),
  .enable (enable0),
  .direction (1'b1),
  .counterValue (counterValue0)
);

counter #(.WIDTH(32)) c1 (
  .reset  (reset | ((ciN == customId) & start & valueB[9])),
  .clock  (clock),
  .enable (enable1 & stall),
  .direction (1'b1),
  .counterValue (counterValue1)
);

counter #(.WIDTH(32)) c2 (
  .reset  (reset | ((ciN == customId) & start & valueB[10])),
  .clock  (clock),
  .enable (enable2 & busIdle),
  .direction (1'b1),
  .counterValue (counterValue2)
);

counter #(.WIDTH(32)) c3 (
  .reset  (reset | ((ciN == customId) & start & valueB[11])),
  .clock  (clock),
  .enable (enable3),
  .direction (1'b1),
  .counterValue (counterValue3)
);

always @(*) begin
  if((ciN == customId) & start) begin
    case (valueA[1:0])
      2'd0: counterValue = counterValue0;
      2'd1: counterValue = counterValue1;
      2'd2: counterValue = counterValue2;
      2'd3: counterValue = counterValue3;
      default: counterValue = 32'b0;
    endcase
  end
  else counterValue = 32'b0;
end

endmodule