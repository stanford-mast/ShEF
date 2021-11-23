module test_status
#(
    parameter         PREFIX  = "TEST_MODULE",
    parameter integer TIMEOUT = 100
)
(
    input wire      clk,
    input wire      reset,
    input wire      fail,
    input wire      pass
);

task watchdog;
  input integer timeout;
  begin
    repeat(timeout) begin
        #1;
    end
    $display;
    $display("ERROR: Timeout. Increase the parameter TIMEOUT of test_status module to prevent early termination of test bench");
    test_fail;
  end
endtask

initial
    check_status;

//-------------------------------------------------------------------
task automatic start;
    begin
        $display;
        $write("%c[1;34m",27);
        $display ("***********************************************");
        $display (PREFIX, " - Test Begin");
        $display ("***********************************************");
        $write("%c[0m",27);
        $display;
    end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic test_fail;
    begin
        $display;
        $write("%c[1;31m",27);
        $display ("***********************************************");
        $display (PREFIX, " - Test Failed");
        $display ("***********************************************");
        $write("%c[0m",27);
        $display;
        $fatal;
    end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic test_pass;
    begin
        $display;
        $write("%c[1;32m",27);
        $display ("***********************************************");
        $display (PREFIX, " - Test Passed");
        $display ("***********************************************");
        $write("%c[0m",27);
        $display;
        $finish;
    end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic check_status;
    begin
        wait ((!reset) && (pass || fail));
        if (fail === 1'b1)
        begin
            test_fail;
        end
        else if (pass === 1'b1)
            test_pass;
        begin
        end
    end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic finish;
    begin
        $display;
        $display ("***********************************************");
        $display (PREFIX, " - Test Finished");
        $display ("***********************************************");
        $display;
        $finish;
    end
endtask
//-------------------------------------------------------------------
endmodule
