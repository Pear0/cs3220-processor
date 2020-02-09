//
// Created by Will Gulian on 10/27/19.
//

#include <chrono>
#include <fstream>
#include <iostream>
#include <memory>
#include <random>
#include "testbench.h"
#include "Vcore.h"
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

void load_memory(Vcore *core, const std::vector<uint32_t> &words) {
  auto &ram = core->core__DOT__imem__DOT__memory;

  for (size_t i = 0; i < words.size(); i++) {
    ram[i] = words[i];
  }
}

std::vector<uint32_t> read_expected(const std::string &file) {
  std::vector<uint32_t> words;

  std::ifstream infile(file);

  unsigned char temp[4];
  int read = 0;

  for (std::string line; std::getline(infile, line); ) {

    int i = line.find(" = ", 0);
    i += 3;

    std::string s;
    s += "0x";
    s += line.substr(i, 8);

    auto result = (uint32_t ) std::stoul(s, nullptr, 16);

    words.push_back(result);
  }

  return words;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  TESTBENCH<Vcore> *tb = new TESTBENCH<Vcore>();

  auto &ram = tb->m_core->core__DOT__imem__DOT__memory;
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

  load_memory(tb->m_core, words);

  std::cout << std::hex << (uint32_t) ram[64] << "\n";

#else
  ram[0] = 0x0d20FFFF;
  ram[1] = 0x0d100003;
  ram[2] = 0xb8312000;
  ram[3] = 0x08403000;
#endif

#define DO_TRACE 1

//  tb->m_core->tl45_comp__DOT__dprf__DOT__registers[4] = 0;
//  tb->m_core->tl45_comp__DOT__dprf__DOT__registers[7] = 0x80000000;

#if DO_TRACE
  tb->opentrace("trace.vcd");
#endif

  tb->reset();

  while (!tb->done() && (!(DO_TRACE) || tb->m_tickcount < 100 * 200)) {
    tb->tick();
  }

  exit(EXIT_SUCCESS);
}