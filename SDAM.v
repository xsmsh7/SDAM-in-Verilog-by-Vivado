module SDAM (
    input wire scl,           // Serial clock
    input wire sda,           // Serial data input
    input wire reset_n,       // Active low reset
    output reg dvalid,        // Parallel data valid
    output reg [15:0] dout,   // Parallel data output
    output reg avalid,        // Parallel address valid
    output reg [7:0] aout     // Parallel address output
);

// State encoding
localparam IDLE        = 3'b000,
           CMD_TRIGGER = 3'b001,
           ADDR_COLLECT = 3'b010,
           DATA_COLLECT = 3'b011,
           OUTPUT      = 3'b100;

reg [2:0] state, next_state;  // Current and next state
reg [3:0] bit_count;          // Bit counter (4 bits for up to 16)
reg [7:0] address;            // Address register
reg [15:0] data;              // Data register

// State transition
always @(posedge scl or negedge reset_n) begin
    if (!reset_n)
        state <= IDLE;
    else
        state <= next_state;
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (sda == 0) // Trigger on SDA low
                next_state = CMD_TRIGGER;
            else
                next_state = IDLE;
        end
        CMD_TRIGGER: begin
            next_state = ADDR_COLLECT;
        end
        ADDR_COLLECT: begin
            if (bit_count == 7)
                next_state = DATA_COLLECT;
            else
                next_state = ADDR_COLLECT;
        end
        DATA_COLLECT: begin
            if (bit_count == 15)
                next_state = OUTPUT;
            else
                next_state = DATA_COLLECT;
        end
        OUTPUT: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Independent bit counter logic
always @(posedge scl or negedge reset_n) begin
    if (!reset_n)
        bit_count <= 4'b0;
    else if (state == ADDR_COLLECT || state == DATA_COLLECT) begin
        if (bit_count == (state == ADDR_COLLECT ? 7 : 15)) 
            bit_count <= 4'b0; // Reset counter at the end of each phase
        else
            bit_count <= bit_count + 1; // Increment counter
    end else
        bit_count <= 4'b0; // Reset counter outside collection phases
end

// Data and address collection
always @(posedge scl or negedge reset_n) begin
    if (!reset_n) begin
        address <= 8'b0;
        data <= 16'b0;
        dout <= 16'b0;
        aout <= 8'b0;
        dvalid <= 1'b0;
        avalid <= 1'b0;
    end else begin
        case (state)
            ADDR_COLLECT: address[bit_count] <= sda; // Shift in address LSB first
            DATA_COLLECT: data[bit_count] <= sda;    // Shift in data LSB first
            OUTPUT: begin
                dout <= data;
                aout <= address;
                dvalid <= 1'b1;
                avalid <= 1'b1;
            end
            default: begin
                dvalid <= 1'b0;
                avalid <= 1'b0;
            end
        endcase
    end
end

endmodule
