`timescale 1 ns / 10 ps

interface divide_if #(
    parameter int unsigned DIVIDEND_WIDTH,
    parameter int unsigned DIVISOR_WIDTH
) (
    input logic clk
);
    logic rst_n;
    logic [DIVIDEND_WIDTH-1:0] in_dividend;
    logic [DIVISOR_WIDTH-1:0] in_divisor;
    logic in_valid;
    logic [DIVIDEND_WIDTH-1:0] out_quotient;
    logic out_divz;
    logic out_done;
endinterface

class divide_item #(
    DIVIDEND_WIDTH,
    DIVISOR_WIDTH
);
    rand bit [DIVIDEND_WIDTH-1:0] in_dividend;
    rand bit [DIVISOR_WIDTH-1:0] in_divisor;
    rand bit in_valid;

    constraint c_in_valid_dist {
        in_valid dist {
            0 :/ 90,
            1 :/ 10
        };
    }

    constraint c_in_dividend_dist {
        in_dividend dist {
            0 :/ 5,
            [DIVIDEND_WIDTH-1:1] :/ 95
        };
    }
endclass

class generator #(
    DIVIDEND_WIDTH,
    DIVISOR_WIDTH
);
    

endclass



module divide_tb #(

);

    
endmodule