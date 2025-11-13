// Utility helpers for formatting and parsing

// Forward declaration for dependency in FormatPrice
int PriceDigits();

class FiboUtils
{
public:
   static string Trim(const string &v)
   {
      string r=v;
      StringTrimLeft(r);
      StringTrimRight(r);
      return r;
   }

   static string TrimTrailingZeros(const string &value)
   {
      string out=value;
      int len=StringLen(out);
      while(len>0 && StringGetCharacter(out,len-1)=='0')
      {
         out=StringSubstr(out,0,len-1);
         len--;
      }
      if(len>0 && StringGetCharacter(out,len-1)=='.')
         out=StringSubstr(out,0,len-1);
      if(StringLen(out)==0)
         return "0";
      return out;
   }

   static string FormatPrice(double value){ return DoubleToString(value, PriceDigits()); }
   static string FormatPercentValue(double value){ return TrimTrailingZeros(DoubleToString(value, 8)); }
   static string FormatRatioUnit(double ratio){ return TrimTrailingZeros(DoubleToString(ratio, 8)); }
   static string FormatRatioAsPercent(double ratio){ return TrimTrailingZeros(DoubleToString(ratio*100.0, 8)); }
   static string FormatGenericValue(double value, int digits)
   {
      int useDigits = (digits<0 ? 0 : digits);
      return TrimTrailingZeros(DoubleToString(value, useDigits));
   }

static bool ParseRatiosTo(const string &text, double &arr[])
   {
      ArrayResize(arr,0);
      string tok[]; int c=StringSplit(text,',',tok);
      if(c<=0) return false;
      for(int i=0;i<c;i++){ string t=Trim(tok[i]); if(StringLen(t)==0) continue;
         double r=StringToDouble(t); if(r<=0.0) continue;
         int n=ArraySize(arr)+1; ArrayResize(arr,n); arr[n-1]=r; }
      return ArraySize(arr)>0;
   }

   static bool IsSeries(const datetime &time[],int total){ return (total>1 && time[0]>time[1]); }
};
