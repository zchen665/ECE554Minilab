// Copyright (c) 2020 University of Florida
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Greg Stitt
// University of Florida
//
// This example demonstrates an AFU wrapper class built around the OPAE API 
// to do the following:
// 1) request an FPGA with a specific AFU
// 2) read and write from a memory-mapped register in the FPGA 

#include <cstdlib>
#include <iostream>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <climits>
#include <unistd.h>

#include <opae/utils.h>

#include "AFU.h"

using namespace std;

// Auto-generated by OPAE's afu_json_mgr script
#include "afu_json_info.h"

//=========================================================
// Define the address of the memory-mapped register according the address
// that was used in the RTL code.
//
// NOTE: Ideally this could be generated with a .json file just like the
// AFU_ACCEL_UUID. Without auto-generation, you must manually ensure that
// the addresses match between the RTL code and software code.
//=========================================================
#define USER_REG_ADDR 0x0020

#define PANIC(E_C, MSG) if(!(E_C)) { fprintf(stderr, MSG); exit(1);}

typedef int8_t AB_TYPE;
typedef int16_t C_TYPE;
#define DIM 16
#define MAX_VAL _UI16_MAX
#define DEBUG true

AB_TYPE A_vals[DIM][DIM];
AB_TYPE B_vals[DIM][DIM];
C_TYPE output[DIM][DIM];
C_TYPE output_reference[DIM][DIM];

// Reflect Endian
template<int width, class BT> BT ref_end(BT in)
{
	int bytes = width / 8;
	BT src = in;
	BT ret = 0;
	char* wh = reinterpret_cast<char*>(&src);
	char* dst = reinterpret_cast<char*>(&ret);
	for(int itr = 0; itr < bytes; ++itr)
	{
		dst[itr] = wh[bytes - 1 - itr];
	}

	if(DEBUG) printf("ref_end: %lx -> %lx\n", src, ret);

	return ret;
}

template<int base_addr> void send_row_X(uint16_t row, AB_TYPE* vals, AFU& afu)
{
	uint64_t real_addr = base_addr + row * 8;
	uint64_t data_word = 0;

	// Pack each of the values into single 64-bit word
	for(int t = 0; t < 8; ++t)
	{
		data_word |= ((static_cast<uint64_t>(vals[t]) & 0x0FF) << (t * sizeof(AB_TYPE)*8));
	}


	uint64_t data_word_cal = data_word;// ref_end<64, uint64_t>(data_word);

	if(DEBUG) printf("data word val, addr: %lx | %lx\n", data_word_cal, real_addr);

	// Do MMIO Write of Data Word
	afu.write(real_addr, data_word_cal);
}

void send_row_A(uint16_t row, AB_TYPE * vals, AFU& afu) { send_row_X<0x100>(row, vals, afu); }
void send_row_B(uint16_t row, AB_TYPE * vals, AFU& afu) { send_row_X<0x200>(row, vals, afu); }

void send_row_C(uint16_t row, C_TYPE* vals, AFU& afu)
{ // can easily genericize send_row_X further. TODO: do that

	uint64_t wds[2] = {0};

	uint64_t base_addr = 0x300;
	uint64_t lw_addr = base_addr + row * 0x10;
	uint64_t hw_addr = lw_addr + 0x8;

	// Read the two words;
	unsigned bitind = 0;


	// Partition the words into their respective rows
	for(ptrdiff_t ind = 0; ind < 8; ++ind)
	{
		uint64_t base_mask = 0x0FFFF;

		// TODO: unhardcode 16-bit
		bitind = (ind / 4);
		uint64_t shift_count = (ind * 16) % 64;

		// Mask and store
		wds[bitind] |= ((vals[ind] & (base_mask)) << shift_count);
	}

	if(DEBUG)
		fprintf(stdout, "CWRITE: low word, high word, address %lx | %lx @%lx @%lx\n", wds[0], wds[1], lw_addr, hw_addr);

	afu.write(lw_addr, wds[0]);
	afu.write(hw_addr, wds[1]);
}

void unpack_from_C(uint16_t row, C_TYPE * vals, AFU& afu)
{
	uint64_t wds[2] = {0};

	uint64_t base_addr = 0x300;
	uint64_t lw_addr = base_addr + row * 0x10;
	uint64_t hw_addr = lw_addr + 0x8;

	// Read the two words;
	wds[0] = afu.read(lw_addr);
	wds[1] = afu.read(hw_addr);
	unsigned bitind = 0;

//	wds[0] = ref_end<64, uint64_t>(wds[0]);
//	wds[1] = ref_end<64, uint64_t>(wds[1]);

	if(DEBUG)
		fprintf(stdout, "low word, high word, address %lx | %lx @%lx @%lx\n", wds[0], wds[1], lw_addr, hw_addr);

	// Partition the words into their respective rows
	for(ptrdiff_t ind = 0; ind < 8; ++ind)
	{
		uint64_t base_mask = 0x0FFFF;

		// TODO: unhardcode 16-bit
		bitind = (ind / 4);
		uint64_t shift_count = (ind * 16) % 64;

		// Mask and store
		vals[ind] = ((wds[bitind] & (base_mask << shift_count)) >> shift_count);
	}
}

int main(int argc, char *argv[]) {

  try {
    // Create an AFU object to provide basic services for the FPGA. The 
    // constructor searchers available FPGAs for one with an AFU with the
    // the specified ID
    AFU afu(AFU_ACCEL_UUID);

        // Seed random generator with "now"
	timeval tv, start, end, start_compute, end_compute;
	long total_compute, total_time;
	total_compute = 0;
	gettimeofday(&tv, nullptr);
	srand(tv.tv_usec);

	fprintf(stdout, "FULL SYSTEM TEST\n---------------\n");
	fprintf(stdout, "Populating A and B...\n");
	// Generate A vals, B vals.
	for(int y_ind = 0; y_ind < DIM; ++y_ind)
	{
		for(int x_ind = 0; x_ind < DIM; ++x_ind)
		{
			A_vals[y_ind][x_ind] = static_cast<int8_t>(rand() % 255);
			B_vals[y_ind][x_ind] = static_cast<int8_t>(rand() % 255);
		}
	}


	fprintf(stdout, "Calculating reference values of C...\n");
	// Calculate reference C values.
	for(int y_ind = 0; y_ind < DIM; ++y_ind)
	{
		for(int x_ind = 0; x_ind < DIM; ++x_ind)
		{
			// Calculate C
			output_reference[y_ind][x_ind] = 0;

			for(ptrdiff_t wh = 0; wh < DIM; ++wh)
			{
				output_reference[y_ind][x_ind] += A_vals[y_ind][wh] * B_vals[wh][x_ind];
			}
		}
	}

	// Now try it with the AFU.
	
	// Start time
	gettimeofday(&start, nullptr);

	for (ptrdiff_t i = 0; i <DIM; i += 8){
		for (ptrdiff_t j = 0; j < DIM; j += 8){
			// fprintf(stdout, "Calculate block[%d][%d]\n", i, j);
			for (ptrdiff_t ii = 0; ii < 8; ii ++){
				send_row_C(ii, &(output[i+ii][j]),afu);
			}
			// fprintf(stdout, "Sending A and B.\n");
			for (ptrdiff_t k = 0; k <DIM; k += 8){
				for (ptrdiff_t ii = 0; ii < 8; ii ++){
					send_row_A(ii, A_vals[i+ii] + k,afu);
					send_row_B(ii, B_vals[k+ii] + j,afu);
				}	
				gettimeofday(&start_compute, nullptr);
				afu.write(0x0400, 100);
				gettimeofday(&end_compute, nullptr);
				total_compute += end_compute.tv_usec - start_compute.tv_usec;

				for (ptrdiff_t ii = 0; ii < 8; ii ++){
					unpack_from_C(ii, &(output[i+ii][j]),afu);
			  }		
			}
			for (ptrdiff_t ii = 0; ii < 8; ii ++){
				unpack_from_C(ii, &(output[i+ii][j]),afu);
			}			
		}
	}
	
	// Final time
	gettimeofday(&end, nullptr);
	
	for(int r = 0; r < DIM; ++r)
	{
		for(int c = 0; c < DIM; ++c)
		{
			fprintf(stdout, "row: %d, col: %d | got: %hx, expected %hx", r, c, output[r][c], output_reference[r][c]);
			fflush(stdout);
			assert(output[r][c] == output_reference[r][c]);
			fprintf(stdout, " [OK]\n");
		}
	}

	fprintf(stdout, "All tests passed. No errors detected.\n");

	total_time = end.tv_usec - start.tv_usec;
	double ops_rate = 2.0 * DIM *DIM * DIM / static_cast<double>(total_time) * 1000.0;
	double compute_ops_rate = 2.0 * DIM *DIM * DIM / static_cast<double>(total_compute) * 1000.0;
	fprintf(stdout, "Total time: %ld ms, ops rate: %f\n", total_time, ops_rate);
	fprintf(stdout, "Total compute time: %ld ms, compute ops rate: %f\n", total_time, ops_rate);
	return 0;    
  }
  // Exception handling for all the runtime errors that can occur within 
  // the AFU wrapper class.
  catch (const fpga_result& e) {    
    
    // Provide more meaningful error messages for each exception.
    if (e == FPGA_BUSY) {
      cerr << "ERROR: All FPGAs busy." << endl;
    }
    else if (e == FPGA_NOT_FOUND) { 
      cerr << "ERROR: FPGA with accelerator " << AFU_ACCEL_UUID 
	   << " not found." << endl;
    }
    else {
      // Print the default error string for the remaining fpga_result types.
      cerr << "ERROR: " << fpgaErrStr(e) << endl;    
    }
  }
  catch (const runtime_error& e) {    
    cerr << e.what() << endl;
  }
  catch (const opae::fpga::types::no_driver& e) {
    cerr << "ERROR: No FPGA driver found." << endl;
  }

  return EXIT_FAILURE;
}
