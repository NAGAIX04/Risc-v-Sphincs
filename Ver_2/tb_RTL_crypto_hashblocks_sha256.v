`timescale 1ns/1ps

module tb_RTL_crypto_hashblocks_sha256;

  // DUT ports
  reg         CLK;
  reg         RST;       // active-low
  reg         start_in;
  reg  [511:0] message_in;
  reg  [255:0] digest_in;
  wire [255:0] digest_out;
  wire        valid_out;

  // Clock generation: 100 MHz
  initial CLK = 1'b0;
  always #5 CLK = ~CLK; // 10ns period

  // Device Under Test
  RTL_crypto_hashblocks_sha256 dut (
    .CLK(CLK),
    .RST(RST),
    .start_in(start_in),
    .message_in(message_in),
    .digest_in(digest_in),
    .digest_out(digest_out),
    .valid_out(valid_out)
  );

  // SHA-256 initial IV (H0..H7)
  localparam [255:0] SHA256_IV = {
    32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
    32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
  };

  // Test vector: "abc" (single block) padded
  // W[0]..W[15] big-endian, packed MSW->LSW to match DUT slices
  localparam [511:0] BLOCK_ABC = {
    32'h61626380, 32'h00000000, 32'h00000000, 32'h00000000,
    32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
    32'h00000000, 32'h00000000, 32'h00000000, 32'h00000000,
    32'h00000000, 32'h00000000, 32'h00000000, 32'h00000018
  };

  // Expected SHA-256("abc") digest
  localparam [255:0] DIGEST_ABC = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;

  // Simple reset, drive, and check
  initial begin
    // VCD dump for GTKWave
    $dumpfile("tb_sha256.vcd");
    $dumpvars(0, tb_RTL_crypto_hashblocks_sha256);

    // Init
    RST       = 1'b0; // active-low reset asserted
    start_in  = 1'b0;
    message_in = {512{1'b0}};
    digest_in  = {256{1'b0}};

    // Hold reset
    repeat (4) @(posedge CLK);
    RST = 1'b1; // deassert reset

    // Apply inputs for test "abc"
    @(posedge CLK);
    digest_in  <= SHA256_IV;
    message_in <= BLOCK_ABC;

    // Pulse start for 1 cycle
    @(posedge CLK);
    start_in <= 1'b1;
    @(posedge CLK);
    start_in <= 1'b0;

    // Wait for valid flag
    wait (valid_out === 1'b1);
    @(posedge CLK); // sample on clock

    // Report result
    $display("Time %0t: digest_out = %064h", $time, digest_out);

    if (digest_out === DIGEST_ABC) begin
      $display("[PASS] SHA-256(\"abc\") matches expected.");
    end else begin
      $display("[FAIL] Expected %064h", DIGEST_ABC);
    end

    // Small delay then finish
    repeat (5) @(posedge CLK);
    $finish;
  end

endmodule

