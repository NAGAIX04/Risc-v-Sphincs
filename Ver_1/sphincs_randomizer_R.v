`timescale 1ns/1ps

// Compute R = Trunc_16B(HMAC-SHA256(sk_prf, optrand || msg))
// Assumptions:
// - sk_prf: 16 bytes
// - optrand: 16 bytes
// - msg: 32 bytes
// - Padding is performed inside this wrapper for the fixed sizes above.
//   Inner uses two blocks: (K^ipad) || (optrand||msg||pad)
//   Outer uses two blocks: (K^opad) || (inner_digest||pad)
// - Uses RTL_crypto_hashblocks_sha256 (one block per run)

module sphincs_randomizer_R (
  input  wire         CLK,
  input  wire         RST,        // active-low
  input  wire         start,      // pulse 1-cycle to start
  input  wire [127:0] sk_prf,     // 16 bytes
  input  wire [127:0] optrand,    // 16 bytes
  // Allow 33 bytes to match provided vector
  input  wire [263:0] msg,        // 33 bytes
  output reg  [127:0] R,          // 16 bytes (MSB of HMAC digest)
  output reg          valid       // 1-cycle pulse
);

  // SHA-256 IV
  localparam [255:0] SHA256_IV = {
    32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
    32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
  };

  // ipad/opad 64-byte constants
  localparam [511:0] IPAD64 = {64{8'h36}};
  localparam [511:0] OPAD64 = {64{8'h5c}};

  // K' (64 bytes) = sk_prf (16 bytes) || 48 zero bytes
  wire [511:0] Kp = {sk_prf, 384'b0};

  // First blocks of inner/outer (no padding)
  wire [511:0] inner_blk0 = Kp ^ IPAD64;
  wire [511:0] outer_blk0 = Kp ^ OPAD64;

  // Inner last block (for 16B optrand + 33B msg):
  // optrand (16B) || msg (33B) || 0x80 || 6x00 || len(113B)=904 bits
  // Layout: 64 bytes, big-endian byte packing
  localparam [63:0] INNER_LEN_BITS = 64'd904; // (64 + 16 + 33) * 8
  wire [511:0] inner_blk1 = {optrand, msg, 8'h80, 48'h00_0000_0000_00, 64'h0000_0000_0000_0388};
  // The 64-bit length field equals INNER_LEN_BITS = 0x0000000000000380.

  // Outer last block: inner_digest (32B) || 0x80 || 23x00 || len(96B) = 768 bits
  localparam [63:0] OUTER_LEN_BITS = 64'd768; // (64 + 32) * 8
  reg  [511:0] outer_blk1;

  // Core wiring
  reg         core_start;
  reg  [511:0] core_msg;
  reg  [255:0] core_digest_in;
  wire [255:0] core_digest_out;
  wire        core_valid_out;

  RTL_crypto_hashblocks_sha256 core (
    .CLK(CLK),
    .RST(RST),
    .start_in(core_start),
    .message_in(core_msg),
    .digest_in(core_digest_in),
    .digest_out(core_digest_out),
    .valid_out(core_valid_out)
  );

  // FSM
  localparam S_IDLE    = 4'd0;
  localparam S_I0_P    = 4'd1;  // start inner blk0
  localparam S_I0_W    = 4'd2;  // wait
  localparam S_I1_P    = 4'd3;  // start inner blk1
  localparam S_I1_W    = 4'd4;  // wait
  localparam S_O0_P    = 4'd5;  // start outer blk0
  localparam S_O0_W    = 4'd6;  // wait
  localparam S_O1_P    = 4'd7;  // start outer blk1
  localparam S_O1_W    = 4'd8;  // wait
  localparam S_DONE    = 4'd9;

  reg [3:0] state, state_n;
  reg [255:0] inner_digest;
  reg [255:0] outer_mid;

  // Next-state outer blk1 depends on inner_digest
  always @* begin
    // Build: inner_digest (32B) || 0x80 || 23x00 || 64-bit length 0x0000000000000300
    outer_blk1 = {inner_digest, 8'h80, 184'h0, 64'h0000_0000_0000_0300};
  end

  // FSM seq
  always @(posedge CLK or negedge RST) begin
    if (RST == 1'b0) begin
      state <= S_IDLE;
      inner_digest <= 256'b0;
      outer_mid    <= 256'b0;
      R            <= 128'b0;
      valid        <= 1'b0;
    end else begin
      state <= state_n;
      // Latch results on valid pulses for the two block chains
      if (state == S_I1_W && core_valid_out) begin
        inner_digest <= core_digest_out;
      end
      if (state == S_O0_W && core_valid_out) begin
        outer_mid <= core_digest_out;
      end
      if (state == S_O1_W && core_valid_out) begin
        // Truncate to top 16 bytes
        R     <= core_digest_out[255:128];
        valid <= 1'b1;
      end else begin
        valid <= 1'b0;
      end
    end
  end

  // FSM comb + core drive
  always @* begin
    // defaults
    state_n        = state;
    core_start     = 1'b0;
    core_msg       = 512'b0;
    core_digest_in = 256'b0;

    case (state)
      S_IDLE: begin
        if (start) begin
          // inner blk0 with IV
          core_start     = 1'b1;
          core_msg       = inner_blk0;
          core_digest_in = SHA256_IV;
          state_n        = S_I0_W;
        end
      end

      S_I0_W: begin
        if (core_valid_out) begin
          state_n        = S_I1_P;
        end
      end

      S_I1_P: begin
        core_start     = 1'b1;
        core_msg       = inner_blk1;
        core_digest_in = core_digest_out; // chaining from blk0
        state_n        = S_I1_W;
      end

      S_I1_W: begin
        if (core_valid_out) begin
          state_n = S_O0_P;
        end
      end

      S_O0_P: begin
        core_start     = 1'b1;
        core_msg       = outer_blk0;
        core_digest_in = SHA256_IV;
        state_n        = S_O0_W;
      end

      S_O0_W: begin
        if (core_valid_out) begin
          state_n = S_O1_P;
        end
      end

      S_O1_P: begin
        core_start     = 1'b1;
        core_msg       = outer_blk1;      // includes inner_digest
        core_digest_in = core_digest_out; // chaining from outer blk0
        state_n        = S_O1_W;
      end

      S_O1_W: begin
        if (core_valid_out) begin
          state_n = S_DONE;
        end
      end

      S_DONE: begin
        // wait for next start
        if (start) begin
          core_start     = 1'b1;
          core_msg       = inner_blk0;
          core_digest_in = SHA256_IV;
          state_n        = S_I0_W;
        end
      end

      default: begin
        state_n = S_IDLE;
      end
    endcase
  end

endmodule
