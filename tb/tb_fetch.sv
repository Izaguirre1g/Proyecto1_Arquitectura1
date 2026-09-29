`timescale 1ns/1ps

module tb_fetch;

	//Señales del Device Under Test (dut)
	logic clk;
	logic reset;
	
	logic [31:0] pc;
	logic [127:0] instruction_bundle;

	logic [31:0] pc_out;
	logic [127:0] bundle_out;
	logic valid_out;
	
	//Instancia del módulo que se está probando
	fetch DUT (
		.clk(clk),
		.reset(reset),
		.pc(pc),
		.instruction_bundle(instruction_bundle),
		
		.pc_out(pc_out),
		.bundle_out(bundle_out),
		.valid_out(valid_out)

	);

	//Generador del reloj
	always #5 clk = ~clk;
	
	initial begin
		//Archivo para GTKWave
		$dumpfile("fetch.vcd");
		$dumpvars(0, tb_fetch);

		//Valores iniciales
		clk = 0;
		reset = 1;
		
		pc = 32'h00000000;
		instruction_bundle=128'h0;
		
		//Se espera un ciclo con un reset
		#10;
		//Se levanta el reset
		reset = 0;
		

		//Primer bundle
		pc = 32'h00001000;

		instruction_bundle = 128'h123456789ABCDEF00123456789ABCDEF;

		#10;
		
		//Segundo bundle
		pc=32'h00002000;
		
		instruction_bundle = 128'hFEDCBA9876543210FEDCBA9876543210;
		#10;
		$display("Tiempo=%0t PC=%h PC_OUT=%h VALID=%b",
			$time,
			pc,
			pc_out,
			valid_out);
			$finish;
	end
endmodule
