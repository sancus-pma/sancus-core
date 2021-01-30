/*===========================================================================*/
/*                 SANCUS MODULE INTERRUPT LOGIC                             */
/*---------------------------------------------------------------------------*/
/* Test interrupting/resuming a protected and unprotected Sancus module.     */
/*                                                                           */
/*---------------------------------------------------------------------------*/
/*===========================================================================*/
//`define LONG_TIMEOUT

`define STACK_BASE              (16'h240) //`PER_SIZE + 'h60)
`define STACK_IRQ               (`STACK_BASE) //- 16'd28)
`define STACK_IRQ_INTERRUPTED   (`STACK_IRQ | 16'h1)

`define SM_SSA_PT               (mem26C)
`define SM_SSA_SP               (mem268)
`define SM_SSA_BASE             (16'h26A)

`define TST_MEM                 (mem200)
`define TST_VAL                 (16'hbabe)

reg [15:0] saved_pc;
reg [15:0] saved_sr;

reg [63:0] tsc_val1;
reg [63:0] tsc_val2;

initial
   begin
      $display(" ===============================================");
      $display("|                 START SIMULATION              |");
      $display(" ===============================================");

`define LONG_TIMEOUT
      repeat(5) @(posedge mclk);
      stimulus_done = 0;
      saved_pc <= 0;
      saved_sr <= 0;
      tsc_val1 <= 0;
      tsc_val2 <= 0;

      /* ----------------------  UNPROTECTED SM INTERRUPT --------------- */
      @(r15);
      `CHK_INIT_REGS("init", `STACK_BASE)
      if (`SM_SSA_PT !== `SM_SSA_BASE)  tb_error("====== INIT SSA_PT ======");
      if (sm_1_enabled)                    tb_error("====== SM ENABLED ======");

      $display("\n--- UNPROTECTED INTERRUPT ---");
      repeat(5) @(posedge mclk);
      $display("sending interrupt...");
      irq[9] <= 1;
     
      $display("waiting for handling IRQ...");
      @(posedge handling_irq);
      tsc_val1 <= cur_tsc;
      irq[9] <= 0;
      saved_pc <= r0-2;
      saved_sr <= r2;
      `CHK_INIT_REGS("before unprotected irq", `STACK_BASE)
      if (`SM_SSA_SP!==16'h0)      tb_error("====== SSA_SP before unprotected irq != 0x0 ======");
      
      @(negedge handling_irq);
      tsc_val2 <= cur_tsc;
      repeat(2) @(posedge mclk);
      $display("IRQ logic done: %d cycles", tsc_val2 - tsc_val1);
      if (r2!==`IRQ_UNPR_STATUS)    tb_error("====== UNPROTECTED IRQ SR ======");
      `CHK_IRQ_STACK_UNPROTECTED("after unprotected irq", saved_pc, saved_sr)
      if (`SM_SSA_PT !== `SM_SSA_BASE)  tb_error("====== INIT SSA_PT ======");
      if (`SM_SSA_SP!==16'h0)      tb_error("====== UNPROTECTED IRQ SSA_SP WRITE ======");
      @(`TST_MEM);
      if(`TST_MEM!==`TST_VAL)       tb_error("====== ISR INSTR TWO EXT WORDS ======");

      /* ----------------------  SM INITIALIZATION --------------- */
      $display("\n--- SM INIT ---");
      @(posedge crypto_start);
      tsc_val1 <= cur_tsc;
      @(posedge exec_done);
      tsc_val2 <= cur_tsc;
      repeat(2) @(posedge mclk);
      $display("SM enabled: %d crypto cycles", tsc_val2 - tsc_val1);
      @(posedge crypto_start);
      tsc_val1 <= cur_tsc;
      @(posedge exec_done);
      tsc_val2 <= cur_tsc;
      repeat(2) @(posedge mclk);
      $display("SM enabled: %d crypto cycles", tsc_val2 - tsc_val1);

      while(~sm_1_executing) @(posedge mclk);
      @(r15);
      `CHK_INIT_REGS("init", `STACK_BASE)
      if (`SM_SSA_PT !== `SM_SSA_BASE)  tb_error("====== INIT SSA_PT ======");
      if (!sm_1_enabled)                    tb_error("====== SM NOT ENABLED ======");

      /* ----------------------  PROTECTED SM INTERRUPT --------------- */
      $display("\n--- SM INTERRUPT ---");
      repeat(5) @(posedge mclk);
      $display("sending interrupt...");
      irq[9] <= 1;
      
      $display("waiting for handling IRQ...");
      if (`SM_SSA_PT !== `SM_SSA_BASE)  tb_error("====== INIT SSA_PT ======");
      @(posedge handling_irq);
      tsc_val1 <= cur_tsc;
      irq[9] <= 0;
      saved_pc <= r0-2;
      saved_sr <= r2;
      `CHK_INIT_REGS("before SM irq", `STACK_BASE)
      if (`SM_SSA_SP!==16'h0)      tb_error("====== SSA_SP before SM irq != 0x0 ======");
      
      @(negedge handling_irq);
      tsc_val2 <= cur_tsc;
      repeat(2) @(posedge mclk);
      $display("IRQ logic done: %d cycles", tsc_val2 - tsc_val1);
      `CHK_IRQ_REGS("after SM irq", 16'h0, sm_1_public_start, `IRQ_SM_STATUS)
      `CHK_IRQ_SSA("after SM irq", saved_pc, saved_sr)
      if (`SM_SSA_PT !== `SM_SSA_BASE)  tb_error("====== SSA_PT WRITE ======");
      if (`SM_SSA_SP!==`STACK_IRQ_INTERRUPTED) tb_error("====== SM IRQ SSA_SP INTERRUPTED WRITE VAL ======");
      @(`TST_MEM);
      if(`TST_MEM!==`TST_VAL)       tb_error("====== ISR INSTR TWO EXT WORDS ======");


      /* ----------------------  END OF TEST --------------- */
      $display("waiting for end of test...");
      @(r15==16'h2000);
      if (r1!==`STACK_BASE)         tb_error("====== FINAL SP VALUE =====");

      stimulus_done = 1;
   end
