// program 2    CSE141L   min & max arithmetic distances in double precision data pairs
module test_bench;

// connections to DUT: clock, start (request), done (acknowledge) 
  bit  clk,
       start = 'b1;			          // request to DUT
  wire done;                          // acknowledge from DUT

  logic       [15:0] Dist, 		      // magnitude of difference between two values
                     Min, Max;	      // minimum and maximum difference magnitudes
  logic       [ 4:0] Min1, Min2;      // locations of minimum distance pair
  logic       [ 4:0] Max1, Max2;      // locations of maximum distance pair
  logic signed[15:0] Tmp[32];	      // caches all 16-bit values
  logic signed[16:0] diff;		      // signed difference -- Dist = abs(diff)

  DUT D1(.clk  (clk  ),	              // your design goes here
		 .start(start),
		 .done (done )); 

  always begin
    #50ns clk = 'b1;
	#50ns clk = 'b0;
  end

  initial begin
// load operands for program 1 into data memory
// 32 double-precision operands go into data_mem [0:63]
// first operand = {data_mem[0],data_mem[1]}  
//   endian order doesn't matter for program 1, as long as consistent for all values (why?)
    #100ns;
	Min = 'hffff;						     // start test bench Min at max value
	Max = 'h0;						         // start test bench Max at min value
    for(int i=0; i<32; i++) begin
      {D1.dm.core[2*i],D1.dm.core[2*i+1]} = $random;  // or try other values
      Tmp[i] = {D1.dm.core[2*i],D1.dm.core[2*i+1]};	  // load values into mem, copy to Tmp array
      $display("%d:  %d",i,Tmp[i]);
	end
// do not preload core[64:65] -- these are used by program 1
    D1.dm.core[66] = 'hffff;		         // preset DUT final Min to max possible
    D1.dm.core[67] = 'hffff;
    for(int r=68; r<256; r++)
	  D1.dm.core[r] = 'd0;		             // preset DUT final Max to min possible 
// 	compute correct answers
    for(int j=0; j<32; j++) begin			 // triangular half of 32x32 matrix, minus the major diagonal
      for(int k=j+1; k<32; k++) begin		 // steps through all 2-different-element combinations (not permutations)
	    #1ns Dist = abs(Tmp[j],Tmp[k]);		 // call abs subroutine, which computes magnitude of difference between two values
        if(Dist<Min) begin                   // update arithmetic minimum
          Min = Dist;						 //   value
		  Min2 = j;							 //	  location of data pair
		  Min1 = k;							 //         "
		end  
		if(Dist>Max) begin 			         // update arithmetic maximum
		  Max = Dist;						 //   value
		  Max2 = j;							 //   location of data pair
		  Max1 = k;							 //			"
        end
	  end
    end   
	#200ns start = 'b0; 
    #200ns wait (done);						 // avoid false done signals on startup

// check results in data_mem[66:67] and [68:69] (Minimum and Maximum distances, respectively)
    if(Min == {D1.dm.core[66],D1.dm.core[67]}) 
                              $display("good Min = %d",Min);     // your DUT put correct answer into core[66:67]
	else                      $display("fail Min = %d",Min);	 // your DUT put wrong answer into core[66:67]
                              $display("Min addr = %d, %d",Min1, Min2);
							  $display("Min valu = %d %d",Tmp[Min1], Tmp[Min2]);
							  //{D1.dm.core[2*Min1],D1.dm.core[2*Min1+1]},{D1.dm.core[2*Min2],D1.dm.core[2*Min2+1]});
	if(Max == {D1.dm.core[68],D1.dm.core[69]}) 
	                          $display("good Max = %d",Max);	 // your DUT put correct answer into core[68:69]
	else                      $display("MAD  Max = %d",Max);	 // your DUT put wrong answer into core[68:69]
	                          $display("Max pair = %d, %d",Max1, Max2);
							  $display("Max valu = %d, %d",Tmp[Max1], Tmp[Max2]);
							  //{D1.dm.core[2*Max1],D1.dm.core[2*Max1+1]},{D1.dm.core[2*Max2],D1.dm.core[2*Max2+1]});
    #200ns start = 'b1;
// to do: load operands for program 2 into data memory (reuse program 1 operands is fine here)
	#200ns start = 'b0;
	$stop;
  end

// magnitude of distance between two 16-bit numbers 
  function[15:0] abs(input signed[15:0] a, b);
                 diff = a-b;      	   // raw difference (two's comp)
    if(diff[16]) abs  = -diff;		   // absolute magnitude of diff
    else       	 abs  =  diff;
  endfunction

endmodule