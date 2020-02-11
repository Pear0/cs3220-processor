#include <verilated_vcd_c.h>

template<class MODULE> struct TESTBENCH {
  // Need to add a new class variable
  VerilatedVcdC	*m_trace;
  unsigned long	m_tickcount;
  MODULE	*m_core;

  TESTBENCH(void) {
    // According to the Verilator spec, you *must* call
    // traceEverOn before calling any of the tracing functions
    // within Verilator.
    Verilated::traceEverOn(true);
    // Everything else can stay like it was before

    m_trace = nullptr;
    m_core = new MODULE;
    m_tickcount = 0l;
  }

  virtual ~TESTBENCH(void) {
    delete m_core;
    m_core = NULL;
  }

  // Open/create a trace file
  virtual	void	opentrace(const char *vcdname) {
    if (!m_trace) {
      m_trace = new VerilatedVcdC;
      m_core->trace(m_trace, 99);
      m_trace->open(vcdname);
    }
  }

  // Close a trace file
  virtual void	close(void) {
    if (m_trace) {
      m_trace->close();
      m_trace = NULL;
    }
  }

  virtual void	reset(void) {
    m_core->i_resetn = 0;
    // Make sure any inheritance gets applied
    this->tick();
    m_core->i_resetn = 1;
  }

  virtual void	tick(void) {
    // Make sure the tickcount is greater than zero before
    // we do this
    m_tickcount++;

    // Allow any combinatorial logic to settle before we tick
    // the clock.  This becomes necessary in the case where
    // we may have modified or adjusted the inputs prior to
    // coming into here, since we need all combinatorial logic
    // to be settled before we call for a clock tick.
    //
    m_core->i_sys_clk = 0;
    m_core->eval();

    //
    // Here's the new item:
    //
    //	Dump values to our trace file
    //
    if(m_trace) m_trace->dump(10*m_tickcount-2);

    // Repeat for the positive edge of the clock
    m_core->i_sys_clk = 1;
    m_core->eval();
    if(m_trace) m_trace->dump(10*m_tickcount);

    if (m_core->o_die) {
      if (m_trace) {
        m_tickcount++;
        m_trace->dump(10*m_tickcount);
        m_trace->flush();
      }
      throw std::runtime_error("o_die triggered rising");
    }

    // Now the negative edge
    m_core->i_sys_clk = 0;
    m_core->eval();
    if (m_trace) {
      // This portion, though, is a touch different.
      // After dumping our values as they exist on the
      // negative clock edge ...
      m_trace->dump(10*m_tickcount+5);
      //
      // We'll also need to make sure we flush any I/O to
      // the trace file, so that we can use the assert()
      // function between now and the next tick if we want to.
      m_trace->flush();
    }

    if (m_core->o_die) {
      if (m_trace) {
        m_tickcount++;
        m_trace->dump(10 * m_tickcount);
        m_trace->flush();
      }
      throw std::runtime_error("o_die triggered falling");
    }

  }

  virtual bool	done(void) { return (Verilated::gotFinish()); }
};