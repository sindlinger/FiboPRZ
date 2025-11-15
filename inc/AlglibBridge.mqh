#ifndef __ALGLIB_BRIDGE_MQH__
#define __ALGLIB_BRIDGE_MQH__

#import "mt-bridge.dll"
  int  AlglibOp_PING(
        const double &primary[], int primary_len,
        const double &secondary[], int secondary_len,
        const uchar  &params[],   int param_len,
        double &out_primary[],    int out_primary_cap,   int &out_primary_len,
        double &out_secondary[],  int out_secondary_cap, int &out_secondary_len,
        uchar  &out_extra[],      int out_extra_cap,     int &out_extra_len,
        int timeout_ms);
  int  AlglibOp_CLIENT_CONFIG(
        const double &primary[], int primary_len,
        const double &secondary[], int secondary_len,
        const uchar  &params[],   int param_len,
        double &out_primary[],    int out_primary_cap,   int &out_primary_len,
        double &out_secondary[],  int out_secondary_cap, int &out_secondary_len,
        uchar  &out_extra[],      int out_extra_cap,     int &out_extra_len,
        int timeout_ms);
  int  AlglibOp_FFT_REAL_FORWARD(
        const double &primary[], int primary_len,
        const double &secondary[], int secondary_len,
        const uchar  &params[],   int param_len,
        double &out_primary[],    int out_primary_cap,   int &out_primary_len,
        double &out_secondary[],  int out_secondary_cap, int &out_secondary_len,
        uchar  &out_extra[],      int out_extra_cap,     int &out_extra_len,
        int timeout_ms);
  int  AlglibOp_FFT_REAL_INVERSE(
        const double &primary[], int primary_len,
        const double &secondary[], int secondary_len,
        const uchar  &params[],   int param_len,
        double &out_primary[],    int out_primary_cap,   int &out_primary_len,
        double &out_secondary[],  int out_secondary_cap, int &out_secondary_len,
        uchar  &out_extra[],      int out_extra_cap,     int &out_extra_len,
        int timeout_ms);
  void AlglibBridge_SetKeepAlive(int enabled, int period_ms);
  int  gpu_get_last_error_w(uchar &buf[], int buf_len);
#import

static bool g_alglib_bridge_connected = false;
static int  g_alglib_bridge_keepalive = 0;

bool AlglibBridge_Ping(string &meta_out, const int timeout_ms=3000)
{
   double p[]; double s[]; uchar prm[];
   double outp[]; int outp_len=0;
   double outs[]; int outs_len=0;
   uchar  extra[]; int extra_len=0; ArrayResize(extra, 4096);
   int st = AlglibOp_PING(p,0, s,0, prm,0,
                          outp,0,outp_len,
                          outs,0,outs_len,
                          extra,ArraySize(extra),extra_len,
                          timeout_ms);
   if(st!=0)
      return false;
   meta_out = (extra_len>0 ? CharArrayToString(extra, 0, extra_len, CP_UTF8) : "{}");
   return true;
}

void EncodeIntLE(int value, uchar &buffer[], int offset)
{
   uint v = (uint)value;
   for(int i=0;i<4;i++)
      buffer[offset+i] = (uchar)((v >> (8*i)) & 0xFF);
}

bool AlglibBridge_ClientConfig(int device_index, int stream_count, string &meta_out, const int timeout_ms=3000)
{
   meta_out = "";
   if(stream_count<=0)
      stream_count = 1;
   if(device_index<0)
      device_index = 0;

   if(!AlglibBridge_EnsureConnected())
      return false;

   double primary[]; double secondary[];
   uchar params[];
   ArrayResize(params, 8);
   EncodeIntLE(device_index, params, 0);
   EncodeIntLE(stream_count, params, 4);

   double outp[]; int outp_len=0;
   double outs[]; int outs_len=0;
   uchar extra[]; int extra_len=0; ArrayResize(extra, 2048);

   int st = AlglibOp_CLIENT_CONFIG(primary,0,
                                   secondary,0,
                                   params, ArraySize(params),
                                   outp,0,outp_len,
                                   outs,0,outs_len,
                                   extra,ArraySize(extra),extra_len,
                                   timeout_ms);
   if(st!=0)
      return false;
   meta_out = (extra_len>0 ? CharArrayToString(extra, 0, extra_len, CP_UTF8) : "{}");
   return true;
}

bool AlglibBridge_EnsureConnected(const int total_ms=5000, const int step_ms=200)
{
   if(g_alglib_bridge_connected)
      return true;
   const int attempts = MathMax(1, total_ms/step_ms);
   string meta="";
   for(int i=0;i<attempts;i++)
   {
      if(AlglibBridge_Ping(meta, step_ms))
      {
         g_alglib_bridge_connected = true;
         return true;
      }
      Sleep(step_ms);
   }
   return false;
}

bool AlglibBridge_Start(const int keepalive_ms=10000)
{
   if(g_alglib_bridge_connected)
      return true;
   if(!AlglibBridge_EnsureConnected())
      return false;
   if(keepalive_ms>0)
      AlglibBridge_SetKeepAlive(true, keepalive_ms);
   g_alglib_bridge_keepalive = keepalive_ms;
   return true;
}

bool AlglibBridge_Ready()
{
   return g_alglib_bridge_connected;
}

void AlglibBridge_Stop()
{
   if(g_alglib_bridge_keepalive>0)
      AlglibBridge_SetKeepAlive(false, 0);
   g_alglib_bridge_keepalive = 0;
   g_alglib_bridge_connected = false;
}

string AlglibBridge_LastError()
{
   uchar raw[]; ArrayResize(raw, 4096);
   int lenBytes = gpu_get_last_error_w(raw, ArraySize(raw));
   if(lenBytes<=0)
      return "";
   int lenShorts = lenBytes/2;
   if(lenShorts<=0)
      return "";
   ushort u16[]; ArrayResize(u16, lenShorts);
   for(int i=0;i<lenShorts;i++)
   {
      int base = 2*i;
      int b0 = (base<ArraySize(raw) ? raw[base] : 0);
      int b1 = (base+1<ArraySize(raw) ? raw[base+1] : 0);
      u16[i] = (ushort)(b0 | (b1<<8));
   }
   return ShortArrayToString(u16, lenShorts);
}

bool AlglibBridge_FFTRealForward(const double &series[],
                                 double &outReal[], int &outRealLen,
                                 double &outImag[], int &outImagLen,
                                 string &meta_json,
                                 const int timeout_ms)
{
   if(!AlglibBridge_EnsureConnected())
      return false;
   int len = ArraySize(series);
   if(len<=0)
      return false;

   double secondary[]; ArrayResize(secondary, 0);
   uchar params[]; ArrayResize(params, 0);
   uchar extra[]; int extra_len=0; ArrayResize(extra, 4096);

   double packed[]; ArrayResize(packed, len);
   int packedLen=0;
   double dummySecondary[]; int dummySecondaryLen=0; ArrayResize(dummySecondary, 0);

   int st = AlglibOp_FFT_REAL_FORWARD(series, len,
                                      secondary, 0,
                                      params, 0,
                                      packed, ArraySize(packed), packedLen,
                                      dummySecondary, 0, dummySecondaryLen,
                                      extra, ArraySize(extra), extra_len,
                                      timeout_ms);
   if(st!=0 || packedLen<=0)
   {
      string err = AlglibBridge_LastError();
      Print(StringFormat("[Bridge][Forward] status=%d err=%s", st, err));
      return false;
   }

   if(packedLen%2!=0)
      packedLen--; // garante pares

   int bins = packedLen/2;
    if(bins<=0)
      return false;

   ArrayResize(outReal, bins);
   ArrayResize(outImag, bins);
   for(int i=0;i<bins;i++)
   {
      int base = 2*i;
      outReal[i] = packed[base];
      outImag[i] = packed[base+1];
   }
   outRealLen = bins;
   outImagLen = bins;

   meta_json = (extra_len>0 ? CharArrayToString(extra, 0, extra_len, CP_UTF8) : "{}");
   return true;
}

bool AlglibBridge_FFTRealInverse(const double &specReal[],
                                 const double &specImag[],
                                 double &outSignal[], int &outSignalLen,
                                 string &meta_json,
                                 const int timeout_ms)
{
   if(!AlglibBridge_EnsureConnected())
      return false;

   int lenR = ArraySize(specReal);
   int lenI = ArraySize(specImag);
   int bins = MathMin(lenR, lenI);
   if(bins<=0)
      return false;

   uchar params[]; ArrayResize(params, 0);
   uchar extra[]; int extra_len=0; ArrayResize(extra, 4096);
   double packed[];
   ArrayResize(packed, bins*2);
   for(int i=0;i<bins;i++)
   {
      packed[2*i]   = specReal[i];
      packed[2*i+1] = specImag[i];
   }

   double secondary[]; ArrayResize(secondary, 0);
   double outSecondary[]; int outSecondaryLen=0; ArrayResize(outSecondary, 0);

   int cap = bins*2;
   ArrayResize(outSignal, cap);
   outSignalLen = 0;

   int st = AlglibOp_FFT_REAL_INVERSE(packed, ArraySize(packed),
                                      secondary, 0,
                                      params, 0,
                                      outSignal, ArraySize(outSignal), outSignalLen,
                                      outSecondary, 0, outSecondaryLen,
                                      extra, ArraySize(extra), extra_len,
                                      timeout_ms);
   if(st!=0)
   {
      string err = AlglibBridge_LastError();
      Print(StringFormat("[Bridge][Inverse] status=%d err=%s", st, err));
      return false;
   }

   if(outSignalLen>=0 && outSignalLen<=ArraySize(outSignal))
      ArrayResize(outSignal, outSignalLen);
   else
      ArrayResize(outSignal, 0);

   meta_json = (extra_len>0 ? CharArrayToString(extra, 0, extra_len, CP_UTF8) : "{}");
   return (ArraySize(outSignal)>0);
}

#endif // __ALGLIB_BRIDGE_MQH__

