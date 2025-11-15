#define AE_PARTIAL_BUILD
#define AE_COMPILE_FFT
#include <complex>
#include "alglib-cpp/src/fasttransforms.h"
using namespace alglib;
using std::complex;
#define DLLAPI extern "C" __declspec(dllexport)

DLLAPI bool FFT_RealForward(const double *series, int length, double *outRe, double *outIm)
{
    if(length<=0)
        return false;
    real_1d_array a;
    a.setlength(length);
    for(int i=0;i<length;i++)
        a[i] = series[i];
    complex_1d_array f;
    try{
        fftr1d(a, length, f);
    }catch(...){
        return false;
    }
    int bins = f.length();
    for(int i=0;i<bins;i++)
    {
        alglib::complex cval = f[i];
        outRe[i] = cval.x;
        outIm[i] = cval.y;
    }
    return true;
}
