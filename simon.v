`timescale 1ns / 1ps

module simon (
    input wire clk,
    input wire rst,
    input wire [15:0] ticks_per_milli,
    input wire [3:0] btn,
    output reg [3:0] led,
    output wire sound,
    output reg [2:0] state,
    output reg [9:0] scr = 0
);

  localparam MAX_GAME_LEN = 32;

  wire [9:0] GAME_TONES[3:0];
  assign GAME_TONES[0] = 196;  // G3
  assign GAME_TONES[1] = 262;  // C4
  assign GAME_TONES[2] = 330;  // E4
  assign GAME_TONES[3] = 784;  // G5

  wire [9:0] SUCCESS_TONES[6:0];
  assign SUCCESS_TONES[0] = 330;  // E4
  assign SUCCESS_TONES[1] = 392;  // G4
  assign SUCCESS_TONES[2] = 659;  // E5
  assign SUCCESS_TONES[3] = 523;  // C5
  assign SUCCESS_TONES[4] = 587;  // D5
  assign SUCCESS_TONES[5] = 784;  // G5
  assign SUCCESS_TONES[6] = 0;  // silence

  wire [9:0] GAMEOVER_TONES[3:0];
  assign GAMEOVER_TONES[0] = 622;  // D#5 
  assign GAMEOVER_TONES[1] = 587;  // D5
  assign GAMEOVER_TONES[2] = 554;  // C#5
  assign GAMEOVER_TONES[3] = 523;  // C5

  localparam StatePowerOn = 0;
  localparam StateInit = 1;
  localparam StatePlay = 2;
  localparam StatePlayWait = 3;
  localparam StateUserWait = 4;
  localparam StateUserInput = 5;
  localparam StateNextLevel = 6;
  localparam StateGameOver = 7;

  reg [4:0] seq_counter;
  reg [4:0] seq_length;
  reg [1:0] seq[MAX_GAME_LEN-1:0];
  
  reg [15:0] tick_counter;
  reg [9:0] millis_counter;
  reg [2:0] tone_sequence_counter;
  reg [9:0] sound_freq;

  reg [1:0] next_random;
  reg [1:0] user_input;
  
  reg bool = 0;

  play play1 (
      .clk(clk),
      .rst(rst),
      .ticks_per_milli(ticks_per_milli),
      .freq(sound_freq),
      .sound(sound)
  );

  always @(posedge clk) begin
    if (rst) begin
      seq_length <= 0;
      seq_counter <= 0;
      tick_counter <= 0;
      millis_counter <= 0;
      sound_freq <= 0;
      next_random <= 0;
      state <= StatePowerOn;
      seq[0] <= 0;
      scr <= 0;
      bool = 0;
      led <= 4'b0000;
      
    end else begin
      tick_counter <= tick_counter + 1;
      next_random  <= next_random + 1;

      if (tick_counter == ticks_per_milli) begin
        tick_counter   <= 0;
        millis_counter <= millis_counter + 1;
      end

      case (state)
        StatePowerOn: begin
          led <= 4'b1111;
          led[millis_counter[9:8]] <= 1'b0;
          // Wait until the user presses some button - the delay will seed the random sequence
          if (btn != 0) begin
            state <= StateInit;
            led <= 4'b0000;
            millis_counter <= 0;
          end
        end
        StateInit: begin
          seq[0] <= next_random;
          seq_length <= 1;
          seq_counter <= 0;
          tone_sequence_counter <= 0;
          if (millis_counter == 500) begin
            state <= StatePlay;
          end
        end
        StatePlay: begin
          led <= 0;
          led[seq[seq_counter]] <= 1'b1;
          sound_freq <= GAME_TONES[seq[seq_counter]];
          millis_counter <= 0;
          state <= StatePlayWait;
        end
        StatePlayWait: begin
          if (millis_counter == 300) begin
            led <= 0;
            sound_freq <= 0;
          end
          if (millis_counter == 400) begin
            if (seq_counter + 1 == seq_length) begin
              state <= StateUserWait;
              millis_counter <= 0;
              seq_counter <= 0;
            end else begin
              seq_counter <= seq_counter + 1;
              state <= StatePlay;
            end
          end
        end
        StateUserWait: begin
        bool <= 0;
          led <= 0;
          millis_counter <= 0;
          if (btn != 0) begin
            state <= StateUserInput;
            case (btn)
              4'b0001: user_input <= 0;
              4'b0010: user_input <= 1;
              4'b0100: user_input <= 2;
              4'b1000: user_input <= 3;
              default: state <= StateUserWait;
            endcase
          end
        end
        StateUserInput: begin
          led <= 0;
          led[user_input] <= 1'b1;
          sound_freq <= GAME_TONES[user_input];
          if (millis_counter == 300) begin
            sound_freq <= 0;
            if (user_input == seq[seq_counter]) begin
              if (seq_counter + 1 == seq_length) begin
                millis_counter <= 0;
                seq[seq_length] <= next_random;
                seq_length <= seq_length + 1;
//                local_score <= local_score + 1;  // Increment score
//                score <= local_score;  // Update the output score
                state <= StateNextLevel;
              end else begin
                seq_counter <= seq_counter + 1;
                state <= StateUserWait;
              end
            end else begin
              millis_counter <= 0;
              state <= StateGameOver;
            end
          end
        end
        StateNextLevel: begin
          if (bool == 0) 
          begin
          scr <= scr + 1;
          bool = 1;
          end
          led <= 0;
          if (millis_counter == 150) begin
            if (tone_sequence_counter < 7) begin
              sound_freq <= SUCCESS_TONES[tone_sequence_counter];
            end else begin
              sound_freq <= 0;
              tone_sequence_counter <= 0;
              seq_counter <= 0;
              state <= StatePlay;
            end
            tone_sequence_counter <= tone_sequence_counter + 1;
            millis_counter <= 0;
          end
        end
        StateGameOver: begin
          led <= millis_counter[7] ? 4'b1111 : 4'b0000;

          if (tone_sequence_counter == 4) begin
            // trembling sound
            sound_freq <= GAMEOVER_TONES[3] - 16 + millis_counter[4:0];
            if (millis_counter == 1000) begin
              tone_sequence_counter <= 7;
              sound_freq <= 0;
            end
          end else if (millis_counter == 300) begin
            if (tone_sequence_counter < 4) begin
              sound_freq <= GAMEOVER_TONES[tone_sequence_counter[1:0]];
              tone_sequence_counter <= tone_sequence_counter + 1;
            end
            millis_counter <= 0;
          end

          if (btn != 0) begin
            led <= 4'b0000;
            sound_freq <= 0;
            millis_counter <= 0;
            state <= StateInit;
          end
        end
      endcase
//      // Update the score digits for display
//      if (score >= 1000) score_digits <= score[15:12];
//      else if (score >= 100) score_digits <= score[11:8];
//      else if (score >= 10) score_digits <= score[7:4];
//      else score_digits <= score[3:0];
//      //
    end
  end

endmodule