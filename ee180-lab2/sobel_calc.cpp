#include "opencv2/imgproc/imgproc.hpp"
#include "sobel_alg.h"
#include <arm_neon.h>
using namespace cv;

/*******************************************
 * Model: grayScale
 * Input: Mat img
 * Output: None directly. Modifies a ref parameter img_gray_out
 * Desc: This module converts the image to grayscale
 ********************************************/
void grayScale(Mat& img, Mat& img_gray_out)
{
  // convert to data pointers 
  uint8_t* src = img.data;
  uint8_t* dst = img_gray_out.data;       
    
  // easier to vectorize the multiplication by a constant
  uint8x8_t r_const = vdup_n_u8 (29);   // ~29 = .114 * 256
  uint8x8_t g_const = vdup_n_u8 (151);  // ~150 = .587 * 256
  uint8x8_t b_const = vdup_n_u8 (28);   // ~77 = .299 * 256
  
  // loop over groups of 8 pixels to maximize vectorization
  int n = img.rows * img.cols / 8;
  for (int i = 0; i < n; i++) {
    uint16x8_t  temp;         // larger bit width to preserve larger multiplication - consts multiplied by 256
    uint8x8x3_t rgb  = vld3_u8 (src); // initial RGB value
    uint8x8_t result;
    
    temp = vmull_u8 (rgb.val[0],      r_const);   // temp = R vector * R_const vector
    temp = vmlal_u8 (temp,rgb.val[1], g_const);   // temp = temp + G vector * g_const vector
    temp = vmlal_u8 (temp,rgb.val[2], b_const);   // temp = temp + B vector * b_const vector
    
    result = vshrn_n_u16 (temp, 8);   // reverse the multiply by 256 -> shift right by 8 aka divide by 256
    
    vst1_u8 (dst, result);        // vectorized store for 8bit uint

    src  += 8*3;
    dst += 8;

    }

}

/*******************************************
 * Model: sobelCalc
 * Input: Mat img_in
 * Output: None directly. Modifies a ref parameter img_sobel_out
 * Desc: This module performs a sobel calculation on an image. It first
 *  converts the image to grayscale, calculates the gradient in the x
 *  direction, calculates the gradient in the y direction and sum it with Gx
 *  to finish the Sobel calculation
 ********************************************/
void sobelCalc(Mat& img_gray, Mat& img_sobel_out)
{

	// calculate the convolution - vectorize
    uint8_t* src = img_gray.data;
	//uint8_t* dst = img_outy.data;
	uint8_t* dst = img_sobel_out.data;

	// initialize vars for convolution 
	uint8x8x3_t top, mid, bot, output;              // for loading image data
	int16x8_t top_result, mid_result, bot_result, temp;   // for computing the conv
	int16x8_t sobel_vals_x, sobel_vals_y, compare_arr;    // for finalizing conv vals
	uint16x8_t mask;

	// setup vals
	int n = img_gray.rows * img_gray.cols / 8;
	src += IMG_WIDTH + 1;
	dst += IMG_WIDTH + 1;
	uint8_t* final_addr = src + (IMG_WIDTH * (IMG_HEIGHT - 2));
	
	for (int i = 0; i < n; i++) {

		if ( src >= final_addr ) {
			break;
	    }
		
		for (int j = -1; j < 2; j++) {
			// loads and Y conv
			top = vld3_u8 (src - IMG_WIDTH + j);     // load top row into groups of 3
			top_result = vsubq_s16 ( vreinterpretq_s16_u16 ( vmovl_u8 (top.val[0]) ), vreinterpretq_s16_u16 ( vmovl_u8 (top.val[2]) ) );

			mid = vld3_u8 (src + j);          // load mid row into groups of 3
			temp = vsubq_s16 ( vreinterpretq_s16_u16 ( vmovl_u8 (mid.val[0]) ), vreinterpretq_s16_u16 ( vmovl_u8 (mid.val[2]) ) );
			mid_result = vmulq_n_s16 (temp, 2);

			bot = vld3_u8 (src + IMG_WIDTH + j );     // load bot row into groups of 3
			bot_result = vsubq_s16 ( vreinterpretq_s16_u16 ( vmovl_u8 (bot.val[0]) ), vreinterpretq_s16_u16 ( vmovl_u8 (bot.val[2]) ) );

			// sum the results
			mid_result = vaddq_s16 (mid_result, top_result);
			mid_result = vaddq_s16 (mid_result, bot_result);
			mid_result = vabsq_s16 (mid_result);

			// set values based on summation
			compare_arr = vdupq_n_s16 (255);
			mask = vcltq_s16 (compare_arr, mid_result);
			sobel_vals_x = vbslq_s16 (mask, compare_arr, mid_result);

			// x conv
			top_result = vsubq_s16 ( vreinterpretq_s16_u16 ( vmovl_u8 (top.val[0]) ), vreinterpretq_s16_u16 ( vmovl_u8 (bot.val[0]) ) );
																											  
			temp = vsubq_s16 ( vreinterpretq_s16_u16 ( vmovl_u8 (top.val[1]) ), vreinterpretq_s16_u16 ( vmovl_u8 (bot.val[1]) ) );
			mid_result = vmulq_n_s16 (temp, 2);

			bot_result = vsubq_s16 ( vreinterpretq_s16_u16 ( vmovl_u8 (top.val[2]) ), vreinterpretq_s16_u16 ( vmovl_u8 (bot.val[2]) ) );

			// sum the results - y
			mid_result = vaddq_s16 (mid_result, top_result);
			mid_result = vaddq_s16 (mid_result, bot_result);
			mid_result = vabsq_s16 (mid_result);

			// set the value based on summation
			mask = vcltq_s16 (compare_arr, mid_result);
			sobel_vals_y = vbslq_s16 (mask, compare_arr, mid_result);

			// sum x and y - using sobel_vals_x as total 
			sobel_vals_x = vaddq_s16 (sobel_vals_x, sobel_vals_y);

			mask = vcltq_s16 (compare_arr, sobel_vals_x);
			sobel_vals_x = vbslq_s16 (mask, compare_arr, sobel_vals_x);

			// convert to proper storage type
			output.val[j + 1] = vqmovun_s16 (sobel_vals_x);
		}

		/////////////////////////////////////////////////////
		// store the result
		vst3_u8(dst, output);
		src += 24;
		dst += 24;
	}

}
