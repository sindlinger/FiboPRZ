#property copyright "2025"
#property link      ""
#property version   "3.25"
#property strict
#property indicator_chart_window
#property indicator_plots 0

// Core types and utils first, so includes podem ir ao topo
#include "inc/Types.mqh"

// Prototypes necessários por includes
void Dbg(const string &s);
int PriceDigits();
// Utilidades
#include "inc/FiboUtils.mqh"
// Demais módulos
#include "inc/LabelManager.mqh"
#include "inc/ClusterManager.mqh"
#include "inc/ChartOverlayService.mqh"
#include "inc/Renderer.mqh"
#include "inc/PivotPipeline.mqh"

// Singletons globais
FiboContext g_ctx;
PivotPipeline g_pivot_pipeline;
LabelManager g_label_manager;
ClusterManager g_cluster_manager;
Renderer g_renderer;
ChartOverlayService g_overlay;

// ========================= Inputs =========================

input group   "ZigZag Primário";
input int      InpZZ_Depth                   = 12;    // ZigZag: Depth
input int      InpZZ_Deviation               = 5;     // ZigZag: Deviation
input int      InpZZ_Backstep                = 3;     // ZigZag: Backstep
input bool     InpShowZigZagPrimary          = false; // overlay: desenhar linhas?
input color    InpZigZagPrimaryColor         = clrDodgerBlue;
input int      InpZigZagPrimaryWidth         = 1;
input color    InpZigZagPrimaryPivotColor    = clrDodgerBlue;
input int      InpZigZagPrimaryPivotSize     = 1;
input int      InpZigZagPrimaryStartOffset   = 3;     // ignora X segmentos recentes (cálculo/overlay)

input group   "ZigZag Secundário";
input bool     InpShowZigZagSecondary        = false; // desenha 2º ZigZag?
input int      InpZZ2_Depth                  = 34;    // ZigZag2: Depth
input int      InpZZ2_Deviation              = 8;     // ZigZag2: Deviation
input int      InpZZ2_Backstep               = 5;     // ZigZag2: Backstep
input color    InpZigZagSecondaryColor       = clrMediumOrchid;
input int      InpZigZagSecondaryWidth       = 1;
input color    InpZigZagSecondaryPivotColor  = clrMediumOrchid;
input int      InpZigZagSecondaryPivotSize   = 2;
input int      InpZigZagSecondaryStartOffset = 2;     // ignora X segmentos recentes (cálculo/overlay)

input group   "Pivôs e Pernas";
input int      InpPivotScanLookbackBars  = 3000;   // quantas barras recentes escanear
input int      InpLegsToUse              = 600;    // quantas pernas usar
input bool     InpShowLegs               = true;  // desenhar pernas (visual)
input color    InpLegUpColor             = clrLime;
input color    InpLegDnColor             = clrOrange;
input int      InpLegWidth               = 2;

input group   "Preço & Tempo";
input bool     InpEnableRetUp            = true;  // preço: retração acima de B (R↑)
input bool     InpEnableRetDown          = true;  // preço: retração abaixo de B (R↓)
input bool     InpEnableExpUp            = true;  // preço: expansão acima de B (X↑)
input bool     InpEnableExpDown          = true;  // preço: expansão abaixo de B (X↓)
input bool     InpTimeBothDirections     = true;  // tempo: adiante e atrás
input bool     InpTimeAllLegs            = false; // tempo: todas as pernas? (false = só base)
input int      InpTimeBaseLeg            = 2;     // tempo: perna base (0 = mais recente)
input int      InpTimeMarkersPerLeg      = 3;     // tempo: quantas razões (máx)
input string   InpFibRatios              = "0.0, 0.236, 0.50, 0.618,1.0,1.272,1.618,2.0,2.618,3.618,4.236";
input string   InpTimeFibRatios          = "0.618,1.0,1.618,2.618,4.236";

input group   "Clusters";
input int      InpATR_D1_Periods         = 100;     // ATR(1D) período (média de x dias)
input double   InpClusterRangePctATR     = 0.5;   // ESPESSURA do cluster = % do ATR(1D)
input int      InpClusterMinLines        = 2;     // mínimo de linhas para existir cluster (Recomendado)

input group   "Exibição de Preço";
input ENUM_PRICE_MODE InpPriceMode       = PRICE_CLUSTER; // padrão = LINHAS em CLUSTER
input ENUM_LABEL_DISPLAY_MODE InpPriceLabelMode = LABEL_MODE_DEBUG; // modo de exibição dos rótulos
input int      InpMaxPriceLines          = 300;   // máximo de linhas desenhadas (0 = sem limite)
input ENUM_PRICE_LINE_TRIM_MODE InpMaxLineTrimMode = PRICE_LINE_TRIM_OLDEST; // critério quando exceder o máximo
input int      InpMaxClusterLines        = 150;   // máximo de linhas visíveis em modo cluster (0 = sem limite)
input ENUM_PRICE_LINE_TRIM_MODE InpMaxClusterLineTrimMode = PRICE_LINE_TRIM_OLDEST; // critério para linhas visíveis
input int      InpFibLineWidth           = 1;
input color    InpRetraceLineColor       = clrDeepSkyBlue; // R
input color    InpExpandLineColor        = clrOrangeRed;   // X
input bool     InpShowLabels             = true;           // rótulos (ratio) nas linhas
input bool     InpLabelsMirrorLeft       = true;           // duplicar rótulos no lado esquerdo
input bool     InpLabelShowLeg           = true;           // incluir id da perna no rótulo

input group   "Tempo";
input bool     InpShowTimeFibs           = false;        // liga/desliga marcas de tempo
input bool     InpShowTimeVLines         = true;         // além do ponto, desenhar VLINE
input color    InpTimeDotColor           = clrSilver;
input int      InpTimeDotFontSize        = 8;

input group   "Diagnóstico";
input int      InpRightTextMarginBars    = 6;      // margem à direita (texto)
input int      InpDebugLastRetractions   = 0;    // mostra N retrações mais recentes
input int      InpDebugLastExpansions    = 0;    // mostra N expansões mais recentes
input int      InpDebugLastTimeMarks     = 0;    // mostra N marcas de tempo mais recentes
input bool     InpShowSummary            = true;
input bool     InpSummaryShowBreakdown   = true;
input int      InpSummaryFontSize        = 14;
input bool     InpDebugLog               = false;
input int      InpDebugPrintLimit        = 200;

// ========================= Globais =========================
const string    G_PREF_LINE = "FCZLINE_";
const string    G_PREF_LBL  = "FCZLBL_";
const string    G_PREF_LEG  = "FCZLEG_";
const string    G_PREF_TF   = "FCZTF_";     // pontos de tempo (•)
const string    G_PREF_TFVL = "FCZTFVL_";   // vlines de tempo
const string    G_PREF_ZZ1  = "FCZZPRI_";
const string    G_PREF_ZZ2  = "FCZZSEC_";
const string    G_PREF_ZZ1_PIV = "FCZZPIV1_";
const string    G_PREF_ZZ2_PIV = "FCZZPIV2_";
const string    G_PREF_DBG_RET = "FCZDBG_RET_";
const string    G_PREF_DBG_RET_LBL = "FCZDBG_RETLBL_";
const string    G_PREF_DBG_EXP = "FCZDBG_EXP_";
const string    G_PREF_DBG_EXP_LBL = "FCZDBG_EXPLBL_";
const string    G_PREF_DBG_TIME = "FCZDBG_TIME_DOT_";
const string    G_PREF_DBG_TIME_VL = "FCZDBG_TIME_VL_";

// ========================= Utils =========================
void Dbg(const string &s){ if(!InpDebugLog) return; if(g_ctx.dbg_prints>=InpDebugPrintLimit) return; Print(s); g_ctx.dbg_prints++; }

int PriceDigits()
{
   if(g_ctx.price_digits>0)
      return g_ctx.price_digits;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits<=0)
      digits = (_Digits>0 ? _Digits : 5);
   g_ctx.price_digits = digits;
   return g_ctx.price_digits;
}

//

string BuildPriceLineObjectName(const FibItem &item, int seq)
{
   string ratioToken = FiboUtils::FormatRatioUnit(item.ratio);
   StringReplace(ratioToken, ".", "_");
   string kind = (item.is_expansion ? "X" : "R");
   string dir  = (item.is_up ? "UP" : "DN");
   return StringFormat("%s%s_%s_L%d_%s_%02d", G_PREF_LINE, kind, ratioToken, item.leg_id, dir, seq);
}
string BuildPriceLineComment(const FibItem &item)
{
   string direction = (item.is_up ? "alta" : "baixa");
   string type = (item.is_expansion ? "Expansão" : "Retração");
   return StringFormat("leg=%d ratio=%s %s %s B=%s",
                       item.leg_id,
                       FiboUtils::FormatRatioUnit(item.ratio),
                       type,
                       direction,
                       FiboUtils::FormatPrice(item.price));
}
int LowerBound(const double &A[], int N, double x){
   int lo=0, hi=N;
   while(lo<hi){
      int mid=(lo+hi)>>1;
      if(A[mid] < x) lo=mid+1; else hi=mid;
   }
   return lo;
}
int UpperBound(const double &A[], int N, double x){
   int lo=0, hi=N;
   while(lo<hi){
      int mid=(lo+hi)>>1;
      if(A[mid] <= x) lo=mid+1; else hi=mid;
   }
   return lo;
}


void SortPositionsByPriceDesc(int &positions[], double &prices[], int count)
{
   for(int i=0;i<count-1;i++)
   {
      int best=i;
      for(int j=i+1;j<count;j++)
      {
         if(prices[j] > prices[best])
            best=j;
      }
      if(best!=i)
      {
         double tmpP=prices[i]; prices[i]=prices[best]; prices[best]=tmpP;
         int tmpPos=positions[i]; positions[i]=positions[best]; positions[best]=tmpPos;
      }
   }
}

void SortPositionsByPriceAsc(int &positions[], double &prices[], int count)
{
   for(int i=0;i<count-1;i++)
   {
      int best=i;
      for(int j=i+1;j<count;j++)
      {
         if(prices[j] < prices[best])
            best=j;
      }
      if(best!=i)
      {
         double tmpP=prices[i]; prices[i]=prices[best]; prices[best]=tmpP;
         int tmpPos=positions[i]; positions[i]=positions[best]; positions[best]=tmpPos;
      }
   }
}

bool MarkNextRemoval(const int &positions[], int count, int &cursor, bool &flags[])
{
   while(cursor<count)
   {
      int pos = positions[cursor++];
      if(pos<0 || pos>=ArraySize(flags))
         continue;
      if(flags[pos])
         continue;
      flags[pos]=true;
      return true;
   }
   return false;
}

void EnforceMaxLineLimit(int &idx_price[], const FibItem &all[], int maxLines,
                         ENUM_PRICE_LINE_TRIM_MODE mode,
                         double refPrice, bool refPriceValid)
{
   if(maxLines<=0)
      return;

   int total = ArraySize(idx_price);
   if(total<=maxLines)
      return;

   if(mode==PRICE_LINE_TRIM_OLDEST || !refPriceValid)
   {
      ArrayResize(idx_price, maxLines);
      return;
   }

   int removeCount = total - maxLines;

   bool removeFlags[];
   ArrayResize(removeFlags, total);
   for(int i=0;i<total;i++) removeFlags[i]=false;

   int abovePos[]; double abovePrices[]; int aboveCount=0;
   int belowPos[]; double belowPrices[]; int belowCount=0;

   for(int pos=0; pos<total; ++pos)
   {
      int idx = idx_price[pos];
      if(idx<0 || idx>=ArraySize(all))
         continue;
      double price = all[idx].price;
      if(!MathIsValidNumber(price))
         continue;

      if(price >= refPrice)
      {
         int n = aboveCount+1;
         ArrayResize(abovePos, n);
         ArrayResize(abovePrices, n);
         abovePos[n-1]=pos;
         abovePrices[n-1]=price;
         aboveCount++;
      }
      else
      {
         int n = belowCount+1;
         ArrayResize(belowPos, n);
         ArrayResize(belowPrices, n);
         belowPos[n-1]=pos;
         belowPrices[n-1]=price;
         belowCount++;
      }
   }

   SortPositionsByPriceDesc(abovePos, abovePrices, aboveCount);
   SortPositionsByPriceAsc(belowPos, belowPrices, belowCount);

   int aboveCursor=0, belowCursor=0;
   bool pickAbove=true;

   while(removeCount>0)
   {
      bool removed=false;
      if(pickAbove)
         removed = MarkNextRemoval(abovePos, aboveCount, aboveCursor, removeFlags);
      if(!removed)
         removed = MarkNextRemoval(belowPos, belowCount, belowCursor, removeFlags);
      if(!removed)
      {
         removed = MarkNextRemoval(abovePos, aboveCount, aboveCursor, removeFlags);
         if(!removed)
            removed = MarkNextRemoval(belowPos, belowCount, belowCursor, removeFlags);
      }
      if(!removed)
         break;
      removeCount--;
      pickAbove = !pickAbove;
   }

   int write=0;
   for(int pos=0; pos<total && write<maxLines; ++pos)
   {
      if(removeFlags[pos])
         continue;
      if(write!=pos)
         idx_price[write] = idx_price[pos];
      write++;
   }
   ArrayResize(idx_price, write);
}

// ========================= ATR(1D) =========================
bool GetATR_D1(int atr_periods, double &atr_out)
{
   atr_out=0.0;
   if(atr_periods<=0) return false;
   int h=iATR(_Symbol, PERIOD_D1, atr_periods);
   if(h==INVALID_HANDLE) return false;
   double buf[];
   int copied=CopyBuffer(h,0,0,1,buf);
   IndicatorRelease(h);
   if(copied<=0) return false;
   atr_out=buf[0];
   return (atr_out>0.0);
}

// ========================= Pivôs (apenas ZigZag) =========================
int CollectPivots_ZZ_Handle(int handle,
                            const double &high[],const double &low[],const datetime &time[],
                            int total,int lookback,
                            Pivot &pivots[])
{
   ArrayResize(pivots,0);
   if(total<=0 || handle==INVALID_HANDLE) return 0;

   int use = MathMin(lookback, total);
   bool series = FiboUtils::IsSeries(time, total);
   int from = series? 0 : total - use;
   int to   = series? use-1 : total-1;
   if(from<0) from=0; if(to<0) return 0;

   static double top_buf[], bot_buf[];
   int cTop = CopyBuffer(handle, 0, 0, total, top_buf);
   int cBot = CopyBuffer(handle, 1, 0, total, bot_buf);
   if(cTop<=0 && cBot<=0) return 0;

   for(int i=from; i<=to; ++i)
   {
      bool isHigh = (i<cTop && top_buf[i]!=0.0);
      bool isLow  = (i<cBot && bot_buf[i]!=0.0);
      if(!isHigh && !isLow) continue;
      if(isHigh){
         double price = top_buf[i];
         if(price!=0.0){
            int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
            pivots[n-1].price   = price;
            pivots[n-1].time    = time[i];
            pivots[n-1].is_high = true;
            pivots[n-1].index   = i;
         }
      }
      if(isLow){
         double price = bot_buf[i];
         if(price!=0.0){
            int n=ArraySize(pivots)+1; ArrayResize(pivots,n);
            pivots[n-1].price   = price;
            pivots[n-1].time    = time[i];
            pivots[n-1].is_high = false;
            pivots[n-1].index   = i;
         }
      }
   }

   // ordenar por tempo crescente + deduplicar por tempo
   int N=ArraySize(pivots);
   for(int a=0;a<N-1;a++){
      int best=a;
      for(int b=a+1;b<N;b++) if(pivots[b].time < pivots[best].time) best=b;
      if(best!=a){ Pivot t=pivots[a]; pivots[a]=pivots[best]; pivots[best]=t; }
   }
   int w=0;
   for(int i=0;i<N;i++){
      if(i==0 || pivots[i].time!=pivots[w-1].time){
         if(w!=i) pivots[w]=pivots[i];
         w++;
      }
   }
   ArrayResize(pivots,w);
   return w;
}
int CollectPivots_ZZ(const double &high[],const double &low[],const datetime &time[],
                     int total,int lookback,
                     Pivot &pivots[])
{
   return CollectPivots_ZZ_Handle(g_ctx.zz_handle, high, low, time, total, lookback, pivots);
}

int TrimRecentPivotSegments(Pivot &pivots[], int skip_segments)
{
   int count = ArraySize(pivots);
   if(count<=0) return 0;
   skip_segments = MathMax(0, skip_segments);
   if(skip_segments<=0) return count;

   int segments = MathMax(0, count-1);
   if(skip_segments >= segments){
      ArrayResize(pivots, 0);
      return 0;
   }

   int keep = count - skip_segments;
   if(keep < 2){
      ArrayResize(pivots, 0);
      return 0;
   }

   ArrayResize(pivots, keep);
   return keep;
}

void BuildLegsFromPivots(const Pivot &piv[],int piv_count,int legs_to_use, LegSeg &legs[],int &leg_count)
{
   ArrayResize(legs,0); leg_count=0;
   if(piv_count<2 || legs_to_use<=0) return;

   int start = piv_count-2;
   int built=0;
   for(int i=start; i>=0 && built<legs_to_use; --i)
   {
      Pivot pA = piv[i];
      Pivot pB = piv[i+1];
      PrintFormat("Leg %d: A(idx=%d time=%s price=%g high=%s) B(idx=%d time=%s price=%g high=%s)",
                  built, pA.index, TimeToString(pA.time), pA.price, pA.is_high ? "topo":"fundo",
                  pB.index, TimeToString(pB.time), pB.price, pB.is_high ? "topo":"fundo");

      // precisa ser Topo->Fundo ou vice-versa para haver perna
      if(pA.is_high == pB.is_high){
         Dbg(StringFormat("Leg descartada (mesmo tipo de pivô) idxA=%d idxB=%d", pA.index, pB.index));
         continue;
      }
      // pB deve ser o pivô mais recente
      if(pB.time <= pA.time){
         Dbg(StringFormat("Leg descartada (ordem temporal inválida) tA=%s tB=%s",
                          TimeToString(pA.time), TimeToString(pB.time)));
         continue;
      }

      LegSeg Lg;
      Lg.t1 = pA.time;   Lg.p1 = pA.price;
      Lg.t2 = pB.time;   Lg.p2 = pB.price;
      Lg.a_is_high = pA.is_high;
      Lg.b_is_high = pB.is_high;
      Lg.idx_a = pA.index;
      Lg.idx_b = pB.index;

      Lg.is_up = (Lg.p2>Lg.p1);
      Lg.id    = built;

      int n=ArraySize(legs)+1; ArrayResize(legs,n); legs[n-1]=Lg; built++;
   }
   leg_count=ArraySize(legs);
}


// ========================= Linhas de PREÇO (geração) =================
string RatioTag(double ratio)
{
   double pct=ratio*100.0;
   bool is_exp=(pct>100.0);
   return (is_exp? "X":"R") + FiboUtils::FormatRatioAsPercent(ratio);
}
string BuildLineLabelText(const FibItem &item)
{
   string text = RatioTag(item.ratio);
   text += (item.is_up? "+" : "-");
   if(InpLabelShowLeg) text += StringFormat(" L%d", item.leg_id);
   return text;
}
string BuildPriceLabelIdentity(const FibItem &item)
{
   return StringFormat("L%d_R%s_E%d_U%d",
                       item.leg_id,
                       FiboUtils::FormatRatioUnit(item.ratio),
                       (item.is_expansion? 1 : 0),
                       (item.is_up? 1 : 0));
}


void BuildAllPriceLines(const LegSeg &legs[],int leg_count,
                        LineItem &out[],int &out_count)
{
   ArrayResize(out,0); out_count=0;
   if(leg_count<=0 || ArraySize(g_ctx.fib_ratios)==0) return;

   for(int i=0;i<leg_count;i++)
   {
      if(legs[i].t2 <= legs[i].t1){
         Dbg(StringFormat("Perna %d ignorada em preço (ponto B não é mais recente).", legs[i].id));
         continue;
      }
      double B = legs[i].p2;
      double d = MathAbs(legs[i].p2 - legs[i].p1);
      if(d < _Point) continue;

      bool selRUp   = InpEnableRetUp;
      bool selRDown = InpEnableRetDown;
      bool selXUp   = InpEnableExpUp;
      bool selXDown = InpEnableExpDown;
      double dir    = (legs[i].is_up ? 1.0 : -1.0); // direção positiva = perna de alta

      for(int r=0;r<ArraySize(g_ctx.fib_ratios);r++)
      {
         double ratio = g_ctx.fib_ratios[r];
         bool is_exp  = (ratio>1.0);
         double price = (is_exp ? (B + dir*ratio*d)
                                : (B - dir*ratio*d));
         bool priceAboveB = (price >= B);
         bool allowed = false;

         if(!is_exp){ // RETRAÇÕES sempre no sentido A←B
            allowed = (priceAboveB ? selRUp : selRDown);
         }else{       // EXPANSÕES sempre além de B
            allowed = (priceAboveB ? selXUp : selXDown);
         }
         if(!allowed) continue;

         int n=ArraySize(out)+1; ArrayResize(out,n);
         out[n-1].price=price;
         out[n-1].ratio=ratio;
         out[n-1].is_expansion=is_exp;
         out[n-1].is_up=priceAboveB;
         out[n-1].leg_id=legs[i].id;
         out[n-1].tB=legs[i].t2;
      }
   }
   out_count=ArraySize(out);
}

// BuildPricePipeline and Build are defined inline in inc/PivotPipeline.mqh

// ========================= Fibonacci de TEMPO ========================
void BuildTimeMarks(const LegSeg &legs[], int leg_count, TimeItem &marks[], int &marks_count)
{
   ArrayResize(marks,0); marks_count=0;
   if(ArraySize(g_ctx.time_ratios)==0 || InpTimeMarkersPerLeg<=0 || leg_count<=0) return;

   int ps = PeriodSeconds(); if(ps<=0) ps=60;

   int fromLeg=0, toLeg=-1;
   if(InpTimeAllLegs){ fromLeg=0; toLeg=leg_count-1; }
   else{
      int base=InpTimeBaseLeg; if(base<0) base=0; if(base>=leg_count) base=0;
      fromLeg=base; toLeg=base;
   }

   int count = MathMin(InpTimeMarkersPerLeg, ArraySize(g_ctx.time_ratios));

   for(int L=fromLeg; L<=toLeg; L++)
   {
      long dt = (long)legs[L].t2 - (long)legs[L].t1;
      if(dt<=0){
         Dbg(StringFormat("Perna %d ignorada em tempo (ponto B não é mais recente).", legs[L].id));
         continue;
      }

      for(int i=0;i<count;i++)
      {
         double rr = g_ctx.time_ratios[i];
         long off = (long)(rr * (double)dt);
         long snap = off - (off % ps); // alinhado ao período

         // forward: SEMPRE a partir de B, no MESMO nível de B
         datetime tf = (datetime)((long)legs[L].t2 + snap);
         int n=ArraySize(marks)+1; ArrayResize(marks,n);
         marks[n-1].t=tf; marks[n-1].ratio=rr; marks[n-1].leg_id=legs[L].id; marks[n-1].forward=true; marks[n-1].priceB=legs[L].p2;

         // backward (opcional), no MESMO nível do pivô B
         if(InpTimeBothDirections){
            datetime tb = (datetime)((long)legs[L].t2 - snap);
            n=ArraySize(marks)+1; ArrayResize(marks,n);
            marks[n-1].t=tb; marks[n-1].ratio=rr; marks[n-1].leg_id=legs[L].id; marks[n-1].forward=false; marks[n-1].priceB=legs[L].p2;
         }
      }
   }
   marks_count=ArraySize(marks);
}

// ========================= Unificação ================================
void BuildUnifiedFromLegacy(const LineItem &price[], int pn,
                            const TimeItem &tarr[],  int tn,
                            FibItem &out[], int &out_count,
                            int &idx_price[], int &idx_time[])
{
   ArrayResize(out, 0); out_count = 0;
   ArrayResize(idx_price, 0);
   ArrayResize(idx_time,  0);

   // preço
   for(int i=0;i<pn;i++){
      FibItem it;
      it.kind=FIBK_PRICE; it.ratio=price[i].ratio; it.leg_id=price[i].leg_id;
      it.price=price[i].price; it.is_expansion=price[i].is_expansion; it.is_up=price[i].is_up; it.tB=price[i].tB;
      it.t=0; it.forward=false;
      int n=ArraySize(out)+1; ArrayResize(out,n); out[n-1]=it;
      int p=ArraySize(idx_price)+1; ArrayResize(idx_price,p); idx_price[p-1]=n-1;
   }
   // tempo (no preço do pivô B)
   for(int i=0;i<tn;i++){
      FibItem it;
      it.kind=FIBK_TIME; it.ratio=tarr[i].ratio; it.leg_id=tarr[i].leg_id;
      it.t=tarr[i].t; it.forward=tarr[i].forward;
      it.price=tarr[i].priceB; it.is_expansion=false; it.is_up=false; it.tB=0;
      int n=ArraySize(out)+1; ArrayResize(out,n); out[n-1]=it;
      int p=ArraySize(idx_time)+1; ArrayResize(idx_time,p); idx_time[p-1]=n-1;
   }
   out_count = ArraySize(out);
}

// ========================= Cluster (linhas) =========================
// ClusterManager methods are defined inline in inc/ClusterManager.mqh

// ========================= Desenho =========================
// ========================= Contadores =========================
void CountPriceSubtypes(const FibItem &all[], int allN){ g_ctx.retrace_total=g_ctx.expansion_total=0; for(int i=0;i<allN;i++){ if(all[i].kind!=FIBK_PRICE) continue; if(all[i].is_expansion) g_ctx.expansion_total++; else g_ctx.retrace_total++; } }
void CapturePivotStats(const Pivot &piv[], int piv_count)
{
   g_ctx.pivot_total = piv_count;
   g_ctx.pivot_tops = 0;
   g_ctx.pivot_bottoms = 0;
   for(int i=0;i<piv_count;i++){
      if(piv[i].is_high) g_ctx.pivot_tops++;
      else               g_ctx.pivot_bottoms++;
   }
}

// ========================= Lifecycle =========================
int OnInit()
{
   g_ctx.Reset();
   // Nome curto exibido no MT5 (independente do nome do arquivo)
   IndicatorSetString(INDICATOR_SHORTNAME, "FiboPRZ 3.25");
   if(!FiboUtils::ParseRatiosTo(InpFibRatios, g_ctx.fib_ratios)){ Print("Fibo: não foi possível interpretar as razões de PREÇO."); return INIT_FAILED; }
   FiboUtils::ParseRatiosTo(InpTimeFibRatios, g_ctx.time_ratios);
   g_overlay.ClearByPrefix("FCZ");

   // cria handle do ZigZag (única fonte de pivôs)
   g_ctx.zz_handle = iCustom(_Symbol, _Period, "ZigZag", InpZZ_Depth, InpZZ_Deviation, InpZZ_Backstep);
   if(g_ctx.zz_handle==INVALID_HANDLE){
      Print("Falha ao criar ZigZag via iCustom. Verifique se o indicador padrão 'ZigZag' está disponível.");
      return INIT_FAILED;
   }

   if(InpShowZigZagSecondary){
      g_ctx.zz2_handle = iCustom(_Symbol, _Period, "ZigZag", InpZZ2_Depth, InpZZ2_Deviation, InpZZ2_Backstep);
      if(g_ctx.zz2_handle==INVALID_HANDLE){
         Print("Aviso: ZigZag secundário não pôde ser criado (verifique indicador padrão).");
      }
   }else{
      g_ctx.zz2_handle = INVALID_HANDLE;
   }

   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){
   g_overlay.ClearByPrefix("FCZ");
   if(g_ctx.zz_handle!=INVALID_HANDLE) IndicatorRelease(g_ctx.zz_handle);
    if(g_ctx.zz2_handle!=INVALID_HANDLE) IndicatorRelease(g_ctx.zz2_handle);
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
   g_ctx.dbg_prints=0;
   if(rates_total<2) return rates_total;

   const bool series = FiboUtils::IsSeries(time, rates_total);

   if(g_ctx.prev_label_mode != InpPriceLabelMode){
      g_label_manager.ClearAll();
      g_ctx.prev_label_mode = InpPriceLabelMode;
   }

   // 1) Pivôs & Pernas — conforme a FONTE escolhida
   const int primary_start_offset   = MathMax(0, InpZigZagPrimaryStartOffset);
   const int secondary_start_offset = MathMax(0, InpZigZagSecondaryStartOffset);
   PipelineConfig pipelineCfg;
   pipelineCfg.pivot_lookback = InpPivotScanLookbackBars;
   pipelineCfg.trim_recent_segments = primary_start_offset;
   pipelineCfg.legs_to_use = InpLegsToUse;

   VisualConfig legVisual;
   legVisual.show_legs = InpShowLegs;
   legVisual.leg_up_color = InpLegUpColor;
   legVisual.leg_down_color = InpLegDnColor;
   legVisual.leg_width = InpLegWidth;
   legVisual.right_text_margin_bars = InpRightTextMarginBars;

   g_pivot_pipeline.Configure(pipelineCfg);
   bool price_pipeline_ready = g_pivot_pipeline.Build(high, low, time, rates_total);
   const PricePipelineResult &pricePipeline = g_pivot_pipeline.Result();

   g_overlay.DrawZigZagOverlay(g_ctx.zz_handle,
                     InpShowZigZagPrimary,
                     G_PREF_ZZ1, g_ctx.prev_zz1_count,
                     InpZigZagPrimaryColor, InpZigZagPrimaryWidth,
                     high, low, time, rates_total, InpPivotScanLookbackBars, primary_start_offset,
                     InpShowZigZagPrimary,
                     G_PREF_ZZ1_PIV, g_ctx.prev_zz1_piv_count,
                     InpZigZagPrimaryPivotColor, InpZigZagPrimaryPivotSize);
   g_overlay.DrawZigZagOverlay(g_ctx.zz2_handle,
                     InpShowZigZagSecondary,
                     G_PREF_ZZ2, g_ctx.prev_zz2_count,
                     InpZigZagSecondaryColor, InpZigZagSecondaryWidth,
                     high, low, time, rates_total, InpPivotScanLookbackBars, secondary_start_offset,
                     InpShowZigZagSecondary,
                     G_PREF_ZZ2_PIV, g_ctx.prev_zz2_piv_count,
                     InpZigZagSecondaryPivotColor, InpZigZagSecondaryPivotSize);

   if(!price_pipeline_ready)
      return rates_total;

   CapturePivotStats(pricePipeline.pivots, pricePipeline.pivot_count);
   g_ctx.leg_total = pricePipeline.leg_count;
   g_overlay.DrawLegs(pricePipeline.legs, pricePipeline.leg_count, legVisual);

   ArrayResize(g_ctx.price_all, pricePipeline.price_count);
   ArrayCopy(g_ctx.price_all, pricePipeline.price_lines);
   g_ctx.price_total = pricePipeline.price_count;

   // 2) Linhas PREÇO + TEMPO
   if(InpShowTimeFibs){ BuildTimeMarks(pricePipeline.legs, pricePipeline.leg_count, g_ctx.time_all, g_ctx.time_total); }
   else{ ArrayResize(g_ctx.time_all,0); g_ctx.time_total=0; }

   // 3) Base única + views
   BuildUnifiedFromLegacy(g_ctx.price_all, g_ctx.price_total,
                          g_ctx.time_all,  g_ctx.time_total,
                          g_ctx.all, g_ctx.all_total,
                          g_ctx.view_price, g_ctx.view_time);

   int maxPriceLines = MathMax(0, InpMaxPriceLines);
   double refPriceForTrim = 0.0;
   bool refPriceValid = false;
   if(rates_total>0)
   {
      int latestIdx = (series? 0 : rates_total-1);
      refPriceForTrim = close[latestIdx];
      refPriceValid = MathIsValidNumber(refPriceForTrim);
   }
   EnforceMaxLineLimit(g_ctx.view_price, g_ctx.all, maxPriceLines, InpMaxLineTrimMode, refPriceForTrim, refPriceValid);

   CountPriceSubtypes(g_ctx.all, g_ctx.all_total);

   // 4) PREÇO — modo
   g_renderer.PrepareFrame(time, rates_total, series);
   g_label_manager.BeginFrame();
   if(InpPriceMode==PRICE_RAW)
   {
      g_ctx.visible_cluster_lines = g_renderer.RenderPriceRaw(g_ctx.all, g_ctx.all_total,
                                                              g_ctx.view_price, g_label_manager);
      g_ctx.prz_count = 0;
      ArrayResize(g_ctx.prz, 0);
   }
   else // PRICE_CLUSTER
   {
      double atrD1=0.0; bool okATR = GetATR_D1(InpATR_D1_Periods, atrD1);
      if(!okATR || atrD1<=0.0){
         double sumR=0.0; int N=MathMin(200,rates_total);
         for(int i=0;i<N;i++) sumR += (high[i]-low[i]);
         atrD1 = (N>0? sumR/N : 0.0);
      }
      double cluster_range = atrD1 * (InpClusterRangePctATR/100.0);

      ClusterManager::Config clusterCfg;
      clusterCfg.cluster_range = cluster_range;
      clusterCfg.min_lines = InpClusterMinLines;
      clusterCfg.max_visible_lines = InpMaxClusterLines;
      clusterCfg.trim_mode = InpMaxClusterLineTrimMode;
      clusterCfg.ref_price = refPriceForTrim;
      clusterCfg.ref_price_valid = refPriceValid;

      g_cluster_manager.Analyze(g_ctx.all, g_ctx.all_total,
                                g_ctx.view_price, ArraySize(g_ctx.view_price),
                                clusterCfg);
      const ClusterResult &clusterRes = g_cluster_manager.Result();

      g_ctx.prz_count = clusterRes.zone_count;
      ArrayResize(g_ctx.prz, clusterRes.zone_count);
      ArrayCopy(g_ctx.prz, clusterRes.zones);

      g_ctx.visible_cluster_lines = g_renderer.RenderPriceClusters(g_ctx.all, g_ctx.all_total,
                                                                   g_ctx.view_price,
                                                                   clusterRes,
                                                                   g_label_manager);

      if(InpDebugLog){
         Dbg(StringFormat("[Fibo][%s] Src=ZZ  ATR(1D,p=%d)=%s  Range=%s%%  MinLines=%d  PRZ=%d  ClusterLines=%d  LinesTot=%d",
               _Symbol,
               InpATR_D1_Periods, FiboUtils::FormatPrice(atrD1), FiboUtils::FormatPercentValue(InpClusterRangePctATR),
               InpClusterMinLines,
               g_ctx.prz_count, g_ctx.visible_cluster_lines, ArraySize(g_ctx.view_price)));
      }
   }
   g_label_manager.EndFrame();

   // 5) TEMPO — pontos + vlines (no mesmo nível do pivô B)
   if(InpShowTimeFibs){
      g_renderer.RenderTimeMarks(g_ctx.all, g_ctx.view_time, ArraySize(g_ctx.view_time));
   }else{
      for(int i=0;i<g_ctx.prev_tf_count;i++)    ObjectDelete(ChartID(), G_PREF_TF   + "DOT_" + IntegerToString(i));
      for(int i=0;i<g_ctx.prev_tfvl_count;i++) ObjectDelete(ChartID(), G_PREF_TFVL +          IntegerToString(i));
      g_ctx.prev_tf_count=0; g_ctx.prev_tfvl_count=0;
   }

   // 5.1) Debug overlays independent das janelas/filtros
   g_renderer.RenderDebugOverlays(g_ctx.price_all, g_ctx.price_total,
                                  g_ctx.time_all, g_ctx.time_total,
                                  time, rates_total);

   // 6) RESUMO (visor)
   if(InpShowSummary)
   {
      string ln1 = StringFormat(
         "PRICE  Linhas:%d  EmCluster:%d  PRZs:%d  Range=%s%% ATR(1D,p=%d)",
         ArraySize(g_ctx.view_price), g_ctx.visible_cluster_lines, g_ctx.prz_count,
         FiboUtils::FormatPercentValue(InpClusterRangePctATR), InpATR_D1_Periods
      );
      string ln2 = StringFormat("PRICE  R:%d  X:%d  MinLinhas:%d  Pernas:%d  Topos:%d  Fundos:%d",
                                g_ctx.retrace_total, g_ctx.expansion_total, InpClusterMinLines, g_ctx.leg_total, g_ctx.pivot_tops, g_ctx.pivot_bottoms);
      string ln3 = StringFormat(
         "TIME   Marcas:%d  VLines:%s  (ambas direções=%s  base=%s)   Pivôs=ZigZag",
         ArraySize(g_ctx.view_time), (InpShowTimeVLines? "sim":"não"),
         (InpTimeBothDirections? "sim":"não"), (InpTimeAllLegs? "todas":"base")
      );

      string text = (InpSummaryShowBreakdown ? (ln1+"\n"+ln2+"\n"+ln3) : (ln1+"\n"+ln3));
      g_overlay.ShowSummaryLabel(text);
   }else{
      g_overlay.ClearSummaryLabel();
   }

   return rates_total;
}
