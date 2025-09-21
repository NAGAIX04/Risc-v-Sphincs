`timescale 1ns/1ps

// Compute H_msg = MGF1_SHA256(h, 34 bytes)
// where h = SHA256(R || PKseed || PKroot || msg)
// Fixed sizes to match provided vectors:
//   R:       16 bytes
//   PKseed:  16 bytes
//   PKroot:  16 bytes
//   msg:     33 bytes

module sphincs_compute_H_msg (
  input  wire         CLK,
  input  wire         RST,        // active-low
  input  wire         start,      // pulse 1-cycle
  input  wire [127:0] R_in,
  input  wire [127:0] PKseed,
  input  wire [127:0] PKroot,
  input  wire [263:0] msg,        // 33 bytes
  output reg  [271:0] H_msg,      // 34 bytes
  output reg          valid
);

  // SHA-256 IV
  localparam [255:0] SHA256_IV = {
    32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
    32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
  };

  // Split msg: first 16 bytes for block0, remaining 17 bytes for block1
  wire [127:0] msg_hi16 = msg[263:136];
  wire [135:0] msg_lo17 = msg[135:0];

  // h = SHA256 of 81 bytes in two blocks
  // Block 0 (64B): R(16) || PKseed(16) || PKroot(16) || msg_hi16(16)
  wire [511:0] H_blk0 = {R_in, PKseed, PKroot, msg_hi16};

  // Block 1 (64B): msg_lo17(17) || 0x80 || 38x00 || len=81*8=648 bits
  wire [511:0] H_blk1 = { msg_lo17, 8'h80, 304'h0, 64'h0000_0000_0000_0288 };

  // MGF1 inputs (one block each, 36B message -> single block with pad)
  // T0 = SHA256(h || 0x00000000)
  // T1 = SHA256(h || 0x00000001)
  wire [511:0] MGF1_blk0 = { 256'b0, 256'h0 }; // placeholder (combinational below)
  wire [511:0] MGF1_blk1 = { 256'b0, 256'h0 };

  // Core wiring
  reg          core_start;
  reg  [511:0] core_msg;
  reg  [255:0] core_digest_in;
  wire [255:0] core_digest_out;
  wire         core_valid_out;

  RTL_crypto_hashblocks_sha256 core (
    .CLK(CLK), .RST(RST), .start_in(core_start),
    .message_in(core_msg), .digest_in(core_digest_in),
    .digest_out(core_digest_out), .valid_out(core_valid_out)
  );

  // FSM states
  localparam S_IDLE  = 4'd0;
  localparam S_H0_P  = 4'd1;
  localparam S_H0_W  = 4'd2;
  localparam S_H1_P  = 4'd3;
  localparam S_H1_W  = 4'd4;
  localparam S_M0_P  = 4'd5;
  localparam S_M0_W  = 4'd6;
  localparam S_M1_P  = 4'd7;
  localparam S_M1_W  = 4'd8;
  localparam S_DONE  = 4'd9;

  reg [3:0]  state, state_n;
  reg [255:0] h_digest;
  reg [255:0] T0, T1;

  // Build MGF1 blocks based on h_digest
  wire [511:0] mgf_blk0 = { h_digest, 32'h00000000, 8'h80, 152'h0, 64'h0000_0000_0000_0120 };
  wire [511:0] mgf_blk1 = { h_digest, 32'h00000001, 8'h80, 152'h0, 64'h0000_0000_0000_0120 };

  // Sequential state and latching
  always @(posedge CLK or negedge RST) begin
    if (RST == 1'b0) begin
      state     <= S_IDLE;
      h_digest  <= 256'b0;
      T0        <= 256'b0;
      T1        <= 256'b0;
      H_msg     <= 272'b0;
      valid     <= 1'b0;
    end else begin
      state <= state_n;

      if (state == S_H1_W && core_valid_out) begin
        h_digest <= core_digest_out;
      end
      if (state == S_M0_W && core_valid_out) begin
        T0 <= core_digest_out;
      end
      if (state == S_M1_W && core_valid_out) begin
        T1    <= core_digest_out;
        // First 34 bytes of T0||T1 = 32B of T0 || top 2B of T1
        H_msg <= { T0, core_digest_out[255:240] };
        valid <= 1'b1;
      end else begin
        valid <= 1'b0;
      end
    end
  end

  // Combinational control
  always @* begin
    // defaults
    state_n        = state;
    core_start     = 1'b0;
    core_msg       = 512'b0;
    core_digest_in = 256'b0;

    case (state)
      S_IDLE: begin
        if (start) begin
          core_start     = 1'b1;
          core_msg       = H_blk0;
          core_digest_in = SHA256_IV;
          state_n        = S_H0_W;
        end
      end

      S_H0_W: begin
        if (core_valid_out) begin
          state_n = S_H1_P;
        end
      end

      S_H1_P: begin
        core_start     = 1'b1;
        core_msg       = H_blk1;
        core_digest_in = core_digest_out; // chain from H_blk0
        state_n        = S_H1_W;
      end

      S_H1_W: begin
        if (core_valid_out) begin
          state_n = S_M0_P;
        end
      end

      S_M0_P: begin
        core_start     = 1'b1;
        core_msg       = mgf_blk0;
        core_digest_in = SHA256_IV;
        state_n        = S_M0_W;
      end

      S_M0_W: begin
        if (core_valid_out) begin
          state_n = S_M1_P;
        end
      end

      S_M1_P: begin
        core_start     = 1'b1;
        core_msg       = mgf_blk1;
        core_digest_in = SHA256_IV;
        state_n        = S_M1_W;
      end

      S_M1_W: begin
        if (core_valid_out) begin
          state_n = S_DONE;
        end
      end

      S_DONE: begin
        if (start) begin
          core_start     = 1'b1;
          core_msg       = H_blk0;
          core_digest_in = SHA256_IV;
          state_n        = S_H0_W;
        end
      end

      default: state_n = S_IDLE;
    endcase
  end

endmodule
