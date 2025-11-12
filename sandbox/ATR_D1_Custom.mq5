//+------------------------------------------------------------------+
//|                                                ATR_D1_Custom.mq5 |
//|  Fornece ATR do timeframe D1 via iCustom (buffer 0 = último ATR) |
//+------------------------------------------------------------------+
#property copyright   ""
#property link        ""
#property version     "1.00"
#property strict

#property indicator_separate_window
#property indicator_plots 1
#property indicator_buffers 1
#property indicator_label1  "ATR_D1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue

input int ATR_Period = 14;

double Buf[];
int    hATR = INVALID_HANDLE;

int OnInit()
{
   SetIndexBuffer(0, Buf, INDICATOR_DATA);
   // Mantém DRAW_LINE padrão (sem DRAW_NONE) para evitar warning de buffers
   ArraySetAsSeries(Buf, true);
   IndicatorSetString(INDICATOR_SHORTNAME, "ATR_D1_Custom("+IntegerToString(ATR_Period)+")");

   hATR = iATR(_Symbol, PERIOD_D1, ATR_Period);
   if(hATR==INVALID_HANDLE)
   {
      Print("ATR_D1_Custom: falha ao criar iATR D1");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hATR!=INVALID_HANDLE)
      IndicatorRelease(hATR);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   double a[];
   if(CopyBuffer(hATR,0,0,1,a)<=0)
      return prev_calculated;
   double v = a[0];
   if(!MathIsValidNumber(v) || v<=0.0)
      return prev_calculated;

   // escreve apenas no ponto mais recente (índice 0, série)
   if(rates_total>0)
      Buf[0] = v;

   return rates_total;
}
