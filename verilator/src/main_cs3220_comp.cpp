//
// Created by Will Gulian on 10/27/19.
//

#include <chrono>
#include <fstream>
#include <iostream>
#include <memory>
#include <array>
#include <unordered_map>
#include <random>
#include "testbench.h"
#include "Vcs3220_syn.h"
#include "wb_slave.h"

std::vector<uint32_t> read_file(const std::string &file) {
  std::vector<uint32_t> words;

  FILE *f = fopen(file.c_str(), "r");
  if (!f) {
    return words;
  }

  unsigned char temp[4];
  int read = 0;
  while (true) {

    int r = fread(temp, 1, 4 - read, f);
    if (r == 0) {
      break;
    }

    read += r;

    if (read == 4) {
      words.push_back(temp[0u] << 24u | temp[1u] << 16u | temp[2u] << 8u | temp[3u]);
      read = 0;
    }
  }

  printf("Initialized memory with %zu words\n", words.size());
  fclose(f);

  return words;
}

std::vector<uint32_t> read_hex(const std::string &file) {
  std::vector<uint32_t> words;

  std::ifstream infile(file.c_str());

  std::string line;
  while (std::getline(infile, line)) {
    std::string num;
    num += "0x";
    num += line;

    words.push_back(std::stoul(num, nullptr, 16));
  }

  printf("Initialized memory with %zu words\n", words.size());

  return words;
}

void load_memory(uint32_t *ram, const std::vector<uint32_t> &words) {
  for (size_t i = 0; i < words.size(); i++) {
    ram[i] = words[i];
  }
}

std::vector<uint32_t> read_expected(const std::string &file) {
  std::vector<uint32_t> words;

  std::ifstream infile(file);

  unsigned char temp[4];
  int read = 0;

  for (std::string line; std::getline(infile, line);) {

    int i = line.find(" = ", 0);
    i += 3;

    std::string s;
    s += "0x";
    s += line.substr(i, 8);

    auto result = (uint32_t) std::stoul(s, nullptr, 16);

    words.push_back(result);
  }

  return words;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  auto *tb = new TESTBENCH<Vcs3220_syn>();


  auto &ram = tb->m_core->cs3220_syn__DOT__core__DOT__imem__DOT__memory;
//  auto &dram = tb->m_core->cs3220_syn__DOT__dmem__DOT__memory;
  auto &dram_2 = tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__memory;
//  auto &dram = tb->m_core
#define LOAD
#ifdef LOAD
  if (argc == 1) {
    printf("No file specified\n");
  }

  std::vector<uint32_t> words = read_hex(argv[1]);
  if (words.empty()) {
    printf("Failed to read file or file is empty\n");
    return 1;
  }

  load_memory(ram, words);
//  load_memory(dram, words);
  load_memory(dram_2, words);

  std::cout << std::hex << (uint32_t) ram[words.size() - 1] << "\n" << "@0x" << words.size() - 1 << "\n";

#else
  ram[0] = 0x0d20FFFF;
  ram[1] = 0x0d100003;
  ram[2] = 0xb8312000;
  ram[3] = 0x08403000;
#endif

#define DO_TRACE 0

//  tb->m_core->tl45_comp__DOT__dprf__DOT__registers[4] = 0;
//  tb->m_core->tl45_comp__DOT__dprf__DOT__registers[7] = 0x80000000;

#if DO_TRACE
  tb->opentrace("trace.vcd");
#endif

  tb->reset();
  uint64_t branch_cnt = 0, branch_miss_cnt = 0;
  uint32_t last_seg = 0xFFFFEEEE;
  uint32_t last_led = 0xFFFFEEEE;

  uint32_t conflict_count = 0;
  uint32_t mem_stall_count = 0;
  uint32_t bus_stall = 0;
  uint32_t c2_conflicts = 0;

  std::array<uint32_t, 9> mem_stages{0, 0, 0, 0, 0, 0, 0, 0};

  std::unordered_map<uint32_t, uint32_t> mem_addrs;

  int last_rd[2] = {0, 0};

  while (!tb->done() && (tb->m_tickcount < 100 * 500000)) {
    tb->tick();
//    if (tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__is_br) {
//      branch_cnt++;
//#if DO_TRACE
//      printf("Branch at 0x%08X: predicting to 0x%08X\n", tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__mem_req_addr, tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__next_pc);
//#endif
//    }
//    if (tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__exec_ld_pc) {
//      branch_miss_cnt++;
//#if DO_TRACE
//      printf("Branch predict fail: 0x%08X to 0x%08X\n", tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__rr_pc, tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__exec_br_pc );
//#endif
//    }

//  if (tb->m_tickcount % 10000 == 0) {
//
//    printf("curr_pc: 0x%x\n", tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__rr_pc);
//  }

    int rd = tb->m_core->cs3220_syn__DOT__core__DOT__decode_rd;
    int rs = tb->m_core->cs3220_syn__DOT__core__DOT__decode_rs;
    int rt = tb->m_core->cs3220_syn__DOT__core__DOT__decode_rt;
    if (((rs == last_rd[0] && last_rd[0] != 0) || (rt == last_rd[0] && last_rd[0] != 0))
        || ((rs == last_rd[1] && last_rd[1] != 0) || (rt == last_rd[1] && last_rd[1] != 0))) {
      if (!tb->m_core->cs3220_syn__DOT__core__DOT__decode_stall) {
        c2_conflicts++;
      }
    }

    last_rd[1] = last_rd[0];
    last_rd[0] = rd;


    if (tb->m_core->cs3220_syn__DOT__core__DOT__rr__DOT__conflict) {
      conflict_count++;
    }

    if (tb->m_core->cs3220_syn__DOT__core__DOT__mem_stall) {
      mem_stall_count++;
    }
    if (tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__wb_stall) {
      bus_stall++;
    }

    mem_stages[tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__current_state]++;

    if (tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__mem_addr != 0 &&
        tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__start_tx) {
      mem_addrs[tb->m_core->cs3220_syn__DOT__core__DOT__mem_stage__DOT__mem_addr]++;
    }

    if (tb->m_core->cs3220_syn__DOT__seg__DOT__internal_data != last_seg) {
      last_seg = tb->m_core->cs3220_syn__DOT__seg__DOT__internal_data;
      printf("SEG: 0x%x\n", last_seg);

      if (last_seg == 0xf1) {
        break;
      }
    }
//
//    if (tb->m_core->cs3220_syn__DOT__o_leds != last_led) {
//      last_led = tb->m_core->cs3220_syn__DOT__o_leds;
//      printf("LED: 0x%x\n", last_led);
//      if (last_led != 0xf && last_led != 0) {
//
//        for (int i = 0; i < 16; i++) {
//          printf("%d\n", tb->m_core->cs3220_syn__DOT__dmem__DOT__memory[0x1000/4 + i]);
//        }
//
//        break;
//      }
//    }


//    if (tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__next_pc == tb->m_core->cs3220_syn__DOT__core__DOT__fetch__DOT__r_pc)
//      break;
  }

  printf("Total Cycles: %lu\n", tb->m_tickcount);
  printf("Exec Pipeline Conflict %%: %f\n", 100 * float(conflict_count) / tb->m_tickcount);

  printf("Pipeline C2 conflicts: %%: %f   %u\n", 100 * float(c2_conflicts) / tb->m_tickcount, c2_conflicts);

  printf("Mem Stall %%: %f   %u\n", 100 * float(mem_stall_count) / tb->m_tickcount, mem_stall_count);
  printf("Bus Stall %%: %f\n", 100 * float(bus_stall) / tb->m_tickcount);

  printf("Mem stages:");
  for (int i = 0; i < mem_stages.size(); i++) {
    printf(", %d", mem_stages[i]);
  }
  printf("\n");


  std::vector<uint32_t> keys;
  for (auto it = mem_addrs.begin(); it != mem_addrs.end(); it++) {
    keys.push_back(it->first);
  }

  std::sort(keys.begin(), keys.end());

  for (auto key : keys) {
    printf("0x%x: %u\n", key, mem_addrs[key]);
  }


//  printf("Total Branch: %d, miss:%d, pecent: %%%.4f", branch_cnt, branch_miss_cnt, ((double)branch_miss_cnt*100)/branch_cnt);

  exit(EXIT_SUCCESS);
}