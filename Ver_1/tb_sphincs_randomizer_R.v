`timescale 1ns/1ps

module tb_sphincs_randomizer_R;

  reg         CLK;
  reg         RST;  // active-low
  reg         start;
  reg  [127:0] sk_prf;
  reg  [127:0] optrand;
  reg  [263:0] msg;
  wire [127:0] R;
  wire        valid;

  // Clock 100 MHz
  initial CLK = 1'b0;
  always #5 CLK = ~CLK;

  // DUT
  sphincs_randomizer_R dut (
    .CLK(CLK), .RST(RST), .start(start),
    .sk_prf(sk_prf), .optrand(optrand), .msg(msg),
    .R(R), .valid(valid)
  );

  // Sample vectors from prompt
  // sk_prf = 2fd81a25ccb148032dcd739936737f2d (16B)
  // optrand = 33b3c07507e4201748494d832b6ee2a6 (16B)
  // msg = D81C4D8D734FCBFBEADE3D3F8A039FAA2A2C9957E835AD55B22E75BF57BB556AC8 (33B)
  // Expected R = b77b5397031e67eb585dba86b10b710b (16B)

  localparam [127:0] R_EXP = 128'hb77b5397031e67eb585dba86b10b710b;

  initial begin
    $dumpfile("tb_sphincs_R.vcd");
    $dumpvars(0, tb_sphincs_randomizer_R);

    // Init
    RST   = 1'b0;
    start = 1'b0;
    sk_prf  = 128'h2fd81a25ccb148032dcd739936737f2d;
    optrand = 128'h33b3c07507e4201748494d832b6ee2a6;
    // Provided hex had 66 nibbles; trim to 64 nibbles (32 bytes)
    msg     = 264'hD81C4D8D734FCBFBEADE3D3F8A039FAA2A2C9957E835AD55B22E75BF57BB556AC8;

    repeat (4) @(posedge CLK);
    RST = 1'b1;

    // start
    @(posedge CLK);
    start <= 1'b1;
    @(posedge CLK);
    start <= 1'b0;

    // wait for valid
    wait (valid === 1'b1);
    @(posedge CLK);

    $display("R = %032h", R);
    if (R === R_EXP) begin
      $display("[PASS] R matches expected.");
    end else begin
      $display("[FAIL] Expected %032h", R_EXP);
    end

    repeat (5) @(posedge CLK);
    $finish;
  end
endmodule
