`timescale 1ns/1ps

module tb_sphincs_compute_H_msg;

  reg         CLK;
  reg         RST;   // active-low
  reg         start;
  reg  [127:0] R_in;
  reg  [127:0] PKseed;
  reg  [127:0] PKroot;
  reg  [263:0] msg;
  wire [271:0] H_msg;
  wire        valid;

  // Clock 100 MHz
  initial CLK = 1'b0;
  always #5 CLK = ~CLK;

  sphincs_compute_H_msg dut (
    .CLK(CLK), .RST(RST), .start(start),
    .R_in(R_in), .PKseed(PKseed), .PKroot(PKroot), .msg(msg),
    .H_msg(H_msg), .valid(valid)
  );

  localparam [271:0] H_MSG_EXP = 272'h5b7eb772aecf04c74af07d9d9c1c1f8d3a90dcda00d5bab1dc28daecdc86eb87611e;

  initial begin
    $dumpfile("tb_sphincs_Hmsg.vcd");
    $dumpvars(0, tb_sphincs_compute_H_msg);

    // Inputs
    RST    = 1'b0;
    start  = 1'b0;
    R_in   = 128'hb77b5397031e67eb585dba86b10b710b;
    PKseed = 128'hB505D7CFAD1B497499323C8686325E47;
    PKroot = 128'h4FDFA42840C84B1DDD0EA5CE46482020;
    msg    = 264'hD81C4D8D734FCBFBEADE3D3F8A039FAA2A2C9957E835AD55B22E75BF57BB556AC8;

    repeat (4) @(posedge CLK);
    RST = 1'b1;

    @(posedge CLK);
    start <= 1'b1;
    @(posedge CLK);
    start <= 1'b0;

    // Wait for valid
    wait (valid === 1'b1);
    @(posedge CLK);

    $display("H_msg = %068h", H_msg);
    if (H_msg === H_MSG_EXP) begin
      $display("[PASS] H_msg matches expected.");
    end else begin
      $display("[FAIL] Expected %068h", H_MSG_EXP);
    end

    repeat (5) @(posedge CLK);
    $finish;
  end

endmodule

