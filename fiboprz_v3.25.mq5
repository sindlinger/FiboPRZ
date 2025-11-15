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
color ResolvePriceLineColor(const FibItem &item);
void ClearKMeansLabels();
void RenderKMeansClusterLabels(const double &centers[], const int &counts[],
                               const double &ratios[], int clusterCount,
                               datetime labelRight);
void ClearFFTLabels();
void RenderFFTLabels(const double &prices[], const double &scores[],
                     const double &ratios[], const double &counts[],
                     int count, datetime labelRight);
void ClearFFTTimeLabels();
void RenderFFTTimeLabels(const datetime &times[], const double &scores[],
                         const double &durationsBars[], int count);
void ClearFFTTimeLines();
// Utilidades
#include "inc/FiboUtils.mqh"
// Demais módulos
#include "inc/LabelManager.mqh"
#include "inc/ClusterManager.mqh"
#include "inc/ChartOverlayService.mqh"
#include "inc/Renderer.mqh"
#include "inc/PivotPipeline.mqh"
#import "fft_bridge.dll"
bool FFT_RealForward(const double &series[], int length, double &outRe[], double &outIm[]);
#import

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

input group   "K-Means";
input int      InpKMeansClusterCount     = 3;     // número de centros (k)
input int      InpKMeansMaxIterations    = 20;    // iterações máximas
input int      InpKMeansMinLines         = 3;     // mínimo de linhas por cluster válido
input double   InpKMeansBandPctATR       = 0.5;   // espessura máxima = % ATR(1D) (0 = auto)
input double   InpKMeansFibSnapTolerance = 0.02;  // tolerância p/ encaixar razões (0 = desligado)

input group   "FFT";
input int      InpFFTWindowLegs          = 40;    // pernas mais recentes consideradas
input int      InpFFTResolution          = 128;   // bins (potência de 2 recomendada)
input int      InpFFTTopHarmonics        = 5;     // harmônicos selecionados
input int      InpFFTLevelsToShow        = 5;     // quantos níveis exibir
input double   InpFFTMinAmplitude        = 1.0;   // amplitude mínima do harmônico
input color    InpFFTLineColor           = clrGold; // cor das linhas FFT

input group   "Tempo FFT";
input bool     InpEnableFFTTime          = false;   // desenhar FFT no eixo temporal?
input int      InpFFTTimeWindowLegs      = 40;      // pernas usadas
input int      InpFFTTimeResolution      = 128;     // bins
input int      InpFFTTimeTopHarmonics    = 5;       // harmônicos selecionados
input int      InpFFTTimeLevelsToShow    = 5;       // quantos níveis
input double   InpFFTTimeMinAmplitude    = 1.0;     // amplitude mínima
input color    InpFFTTimeColor           = clrAqua; // cor das linhas temporais

input group   "Exibição de Preço";
input ENUM_PRICE_MODE InpPriceMode       = PRICE_CLUSTER; // modos: Cluster / Raw / K-Means
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
input bool     InpUseRatioColors         = false;          // usar cores específicas por razão?
input string   InpRatioColorMap          = "0.236=#66C2A5;0.382=#8DA0CB;0.500=#A6D854;0.618=#FFD92F;1.000=#E78AC3;1.618=#FC8D62"; // ratio[:R|X]=#RRGGBB separados por ';'

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
const string    G_PREF_KM_LABEL = "FCZKMLBL_";
const string    G_PREF_FFT_LINE = "FCZFFTLINE_";
const string    G_PREF_FFT_LABEL = "FCZFFTLBL_";
const string    G_PREF_FFT_TIME_LINE = "FCZFFTTLINE_";
const string    G_PREF_FFT_TIME_LABEL = "FCZFFTTL_";
const double    RATIO_COLOR_TOL = 1e-6;

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

// ========================= Cores por Ratio =========================
bool HexCharToValue(int ch, int &value)
{
   if(ch>='0' && ch<='9'){ value = ch - '0'; return true; }
   if(ch>='A' && ch<='F'){ value = 10 + (ch - 'A'); return true; }
   if(ch>='a' && ch<='f'){ value = 10 + (ch - 'a'); return true; }
   return false;
}

bool TryParseHexColor(const string &hex, color &out)
{
   int len = StringLen(hex);
   if(len!=6 && len!=8) return false;

   int value=0;
   for(int i=0;i<len;i++)
   {
      int digit=0;
      if(!HexCharToValue(StringGetCharacter(hex,i), digit))
         return false;
      value = (value<<4) | digit;
   }
   out = (color)value;
   return true;
}

bool TryParseDecimalColor(const string &text, color &out)
{
   if(StringLen(text)==0) return false;
   for(int i=0;i<StringLen(text);i++)
   {
      int ch = StringGetCharacter(text,i);
      if(i==0 && (ch=='+' || ch=='-'))
         continue;
      if(ch<'0' || ch>'9')
         return false;
   }
   long value = StringToInteger(text);
   if(value<0) value=0;
   out = (color)value;
   return true;
}

bool TryParseColorToken(const string &token, color &out)
{
   string trimmed = FiboUtils::Trim(token);
   if(StringLen(trimmed)==0)
      return false;
   if(StringGetCharacter(trimmed,0)=='#')
      return TryParseHexColor(StringSubstr(trimmed,1), out);
   if(StringLen(trimmed)>2 && StringGetCharacter(trimmed,0)=='0' &&
      (StringGetCharacter(trimmed,1)=='x' || StringGetCharacter(trimmed,1)=='X'))
      return TryParseHexColor(StringSubstr(trimmed,2), out);
   return TryParseDecimalColor(trimmed, out);
}

int EnsureRatioColorRule(double ratio, RatioColorRule &rules[])
{
   for(int i=0;i<ArraySize(rules);i++)
   {
      if(MathAbs(rules[i].ratio - ratio) <= RATIO_COLOR_TOL)
         return i;
   }
   int idx = ArraySize(rules);
   ArrayResize(rules, idx+1);
   rules[idx].ratio = ratio;
   rules[idx].has_retrace = false;
   rules[idx].has_expansion = false;
   return idx;
}

bool ParseRatioColorEntry(const string &entry, RatioColorRule &rules[])
{
   string trimmed = FiboUtils::Trim(entry);
   if(StringLen(trimmed)==0)
      return false;

   int eqPos = StringFind(trimmed, "=");
   if(eqPos<0)
      return false;

   string left = FiboUtils::Trim(StringSubstr(trimmed, 0, eqPos));
   string colorTok = FiboUtils::Trim(StringSubstr(trimmed, eqPos+1));
   if(StringLen(left)==0 || StringLen(colorTok)==0)
      return false;

   string ratioTok = left;
   string typeTok = "";
   int colonPos = StringFind(left, ":");
   if(colonPos>=0)
   {
      ratioTok = FiboUtils::Trim(StringSubstr(left, 0, colonPos));
      typeTok  = FiboUtils::Trim(StringSubstr(left, colonPos+1));
   }

   double ratio = StringToDouble(ratioTok);
   if(ratio<=0.0)
      return false;

   bool applyRetrace = true;
   bool applyExpansion = true;
   if(StringLen(typeTok)>0)
   {
      string upper = typeTok;
      StringToUpper(upper);
      applyRetrace = (StringFind(upper, "R")>=0);
      applyExpansion = (StringFind(upper, "X")>=0);
      if(!applyRetrace && !applyExpansion)
         return false;
   }

   color parsedColor;
   if(!TryParseColorToken(colorTok, parsedColor))
      return false;

   int idx = EnsureRatioColorRule(ratio, rules);
   if(applyRetrace)
   {
      rules[idx].retrace_color = parsedColor;
      rules[idx].has_retrace = true;
   }
   if(applyExpansion)
   {
      rules[idx].expansion_color = parsedColor;
      rules[idx].has_expansion = true;
   }
   if(!applyRetrace && !applyExpansion)
      return false;
   return true;
}

bool ParseRatioColorMap(const string &text, RatioColorRule &rules[])
{
   ArrayResize(rules, 0);
   string entries[];
   int count = StringSplit(text, ';', entries);
   if(count<=0)
      return false;
   bool any=false;
   for(int i=0;i<count;i++)
   {
      if(ParseRatioColorEntry(entries[i], rules))
         any=true;
   }
   return any;
}

bool TryGetRatioColor(double ratio, bool isExpansion, color &out)
{
   if(!g_ctx.ratio_color_enabled)
      return false;
   for(int i=0;i<ArraySize(g_ctx.ratio_color_rules);i++)
   {
      const RatioColorRule rule = g_ctx.ratio_color_rules[i];
      if(MathAbs(rule.ratio - ratio) > RATIO_COLOR_TOL)
         continue;
      if(isExpansion && rule.has_expansion)
      {
         out = rule.expansion_color;
         return true;
      }
      if(!isExpansion && rule.has_retrace)
      {
         out = rule.retrace_color;
         return true;
      }
      if(rule.has_retrace)
      {
         out = rule.retrace_color;
         return true;
      }
      if(rule.has_expansion)
      {
         out = rule.expansion_color;
         return true;
      }
   }
   return false;
}

color ResolvePriceLineColor(const FibItem &item)
{
   color custom;
   if(TryGetRatioColor(item.ratio, item.is_expansion, custom))
      return custom;
   return (item.is_expansion ? InpExpandLineColor : InpRetraceLineColor);
}

void ConfigureRatioColorsFromInput()
{
   ArrayResize(g_ctx.ratio_color_rules, 0);
   g_ctx.ratio_color_enabled = false;
   if(!InpUseRatioColors)
      return;
   bool ok = ParseRatioColorMap(InpRatioColorMap, g_ctx.ratio_color_rules);
   g_ctx.ratio_color_enabled = ok;
   if(!ok)
   {
      Print("Fibo: mapa de cores por razão inválido (use ratio[:R|X]=#RRGGBB separados por ';').");
   }
}

void ClearKMeansLabels()
{
   for(int i=0;i<g_ctx.prev_kmeans_label_count;i++)
      ObjectDelete(ChartID(), G_PREF_KM_LABEL + IntegerToString(i));
   g_ctx.prev_kmeans_label_count = 0;
}

void RenderKMeansClusterLabels(const double &centers[], const int &counts[],
                               const double &ratios[], int clusterCount,
                               datetime labelRight)
{
   if(clusterCount<=0){
      ClearKMeansLabels();
      return;
   }
   int order[];
   ArrayResize(order, clusterCount);
   for(int i=0;i<clusterCount;i++) order[i]=i;
   for(int a=0;a<clusterCount-1;a++){
      int best=a;
      for(int b=a+1;b<clusterCount;b++)
         if(counts[order[b]] > counts[order[best]]) best=b;
      if(best!=a){
         int tmp=order[a]; order[a]=order[best]; order[best]=tmp;
      }
   }
   int maxLabels = MathMin(clusterCount, MathMax(1, MathMin(5, InpKMeansClusterCount)));
   if(labelRight==0) labelRight = TimeCurrent();
   for(int idx=0; idx<maxLabels; idx++)
   {
      int clusterIdx = order[idx];
      string ratioText = (ratios[clusterIdx]>0.0 ? FiboUtils::FormatRatioUnit(ratios[clusterIdx]) : "-");
      string text = StringFormat("#%d Lin:%d Ratio:%s", idx+1, counts[clusterIdx], ratioText);
      string name = G_PREF_KM_LABEL + IntegerToString(idx);
      g_overlay.UpsertText(name, labelRight, centers[clusterIdx], text, clrYellow, 8, ANCHOR_LEFT);
   }
   for(int i=maxLabels;i<g_ctx.prev_kmeans_label_count;i++)
      ObjectDelete(ChartID(), G_PREF_KM_LABEL + IntegerToString(i));
   g_ctx.prev_kmeans_label_count = maxLabels;
}

void ClearFFTLabels()
{
   for(int i=0;i<g_ctx.prev_fft_label_count;i++)
      ObjectDelete(ChartID(), G_PREF_FFT_LABEL + IntegerToString(i));
   g_ctx.prev_fft_label_count = 0;
}

void RenderFFTLabels(const double &prices[], const double &scores[],
                     const double &ratios[], const double &counts[],
                     int count, datetime labelRight)
{
   if(count<=0){
      ClearFFTLabels();
      return;
   }
   if(labelRight==0) labelRight = TimeCurrent();
   int maxLabels = MathMin(count, 8);
   int order[];
   ArrayResize(order, count);
   for(int i=0;i<count;i++) order[i]=i;
   for(int a=0;a<count-1;a++){
      int best=a;
      for(int b=a+1;b<count;b++)
         if(scores[order[b]] > scores[order[best]]) best=b;
      if(best!=a){
         int tmp=order[a]; order[a]=order[best]; order[best]=tmp;
      }
   }
   for(int idx=0; idx<maxLabels; idx++)
   {
       int src = order[idx];
       string ratioText = (ratios[src]>0.0 ? FiboUtils::FormatRatioUnit(ratios[src]) : "-");
       double rawCount = (ArraySize(counts)>src ? counts[src] : scores[src]);
       string countText = IntegerToString((int)MathRound(rawCount));
       if(rawCount<=0.0)
          countText = "-";
       string text = StringFormat("FFT#%d Lin:%s Amp:%s Ratio:%s",
                                  idx+1,
                                  countText,
                                  FiboUtils::FormatGenericValue(scores[src], 2),
                                  ratioText);
       string name = G_PREF_FFT_LABEL + IntegerToString(idx);
       g_overlay.UpsertText(name, labelRight, prices[src], text, InpFFTLineColor, 8, ANCHOR_LEFT);
   }
   for(int i=maxLabels;i<g_ctx.prev_fft_label_count;i++)
      ObjectDelete(ChartID(), G_PREF_FFT_LABEL + IntegerToString(i));
   g_ctx.prev_fft_label_count = maxLabels;
}

void ClearFFTLines()
{
   for(int i=0;i<g_ctx.prev_fft_line_count;i++)
      ObjectDelete(ChartID(), G_PREF_FFT_LINE + IntegerToString(i));
   g_ctx.prev_fft_line_count = 0;
}

void ClearFFTTimeLabels()
{
   for(int i=0;i<g_ctx.prev_fft_time_label_count;i++)
      ObjectDelete(ChartID(), G_PREF_FFT_TIME_LABEL + IntegerToString(i));
   g_ctx.prev_fft_time_label_count = 0;
}

void RenderFFTTimeLabels(const datetime &times[], const double &scores[],
                         const double &durationsBars[], int count, double priceLevel)
{
   if(count<=0){
      ClearFFTTimeLabels();
      return;
   }
   int maxLabels = MathMin(count, 8);
   int order[];
   ArrayResize(order, count);
   for(int i=0;i<count;i++) order[i]=i;
   for(int a=0;a<count-1;a++){
      int best=a;
      for(int b=a+1;b<count;b++)
         if(scores[order[b]] > scores[order[best]]) best=b;
      if(best!=a){
         int tmp=order[a]; order[a]=order[best]; order[best]=tmp;
      }
   }
   for(int idx=0; idx<maxLabels; idx++)
   {
      int src = order[idx];
      double bars = (ArraySize(durationsBars)>src ? durationsBars[src] : 0.0);
      string text = StringFormat("FFT-T#%d Dur:%s barras",
                                 idx+1,
                                 FiboUtils::FormatGenericValue(bars, 2));
      string name = G_PREF_FFT_TIME_LABEL + IntegerToString(idx);
      g_overlay.UpsertText(name, times[src], priceLevel, text, InpFFTTimeColor, 8, ANCHOR_LEFT);
   }
   for(int i=maxLabels;i<g_ctx.prev_fft_time_label_count;i++)
      ObjectDelete(ChartID(), G_PREF_FFT_TIME_LABEL + IntegerToString(i));
   g_ctx.prev_fft_time_label_count = maxLabels;
}

void ClearFFTTimeLines()
{
   for(int i=0;i<g_ctx.prev_fft_time_line_count;i++)
      ObjectDelete(ChartID(), G_PREF_FFT_TIME_LINE + IntegerToString(i));
   g_ctx.prev_fft_time_line_count = 0;
}

double ComputeRatioFromLeg(const LegSeg &leg, double price)
{
   double span = MathAbs(leg.p2 - leg.p1);
   if(span <= _Point)
      return -1.0;
   if(leg.is_up)
      return (leg.p2 - price)/span;
   return (price - leg.p2)/span;
}

int NextPow2(int value)
{
   int v = 1;
   while(v<value && v<32768)
      v <<= 1;
   return v;
}

bool BuildFFTPriceLevels(const FibItem &items[], int total_items,
                         const int &view_idx[], int view_count,
                         const LegSeg &legs[], int leg_count,
                         int windowLegs, int resolution,
                         int topHarmonics, int levelsToShow, double minAmplitude,
                         double &outPrices[], double &outScores[], double &outRatios[],
                         double &outLineCounts[])
{
   ArrayResize(outPrices,0);
   ArrayResize(outScores,0);
   ArrayResize(outRatios,0);
   ArrayResize(outLineCounts,0);
   if(view_count<=0 || resolution<=0 || topHarmonics<=0 || levelsToShow<=0)
      return false;

   int maxLeg=-1;
   for(int i=0;i<view_count;i++)
   {
      int idx=view_idx[i];
      if(idx<0 || idx>=total_items) continue;
      if(items[idx].kind!=FIBK_PRICE) continue;
      if(items[idx].leg_id > maxLeg)
         maxLeg = items[idx].leg_id;
   }
   if(maxLeg<0)
      return false;
   int legWindow = MathMax(1, windowLegs);
   int legThreshold = MathMax(0, maxLeg - legWindow + 1);

   double priceList[];
   ArrayResize(priceList,0);
   double minPrice=DBL_MAX, maxPrice=-DBL_MAX;
   for(int i=0;i<view_count;i++)
   {
      int idx=view_idx[i];
      if(idx<0 || idx>=total_items) continue;
      const FibItem item = items[idx];
      if(item.kind!=FIBK_PRICE) continue;
      if(item.leg_id < legThreshold) continue;
      double p = item.price;
      if(!MathIsValidNumber(p)) continue;
      int s = ArraySize(priceList);
      ArrayResize(priceList, s+1);
      priceList[s]=p;
      if(p<minPrice) minPrice=p;
      if(p>maxPrice) maxPrice=p;
   }
   int totalLines = ArraySize(priceList);
   if(totalLines<=0)
      return false;
   double range = maxPrice - minPrice;
   if(range <= _Point)
      return false;

   int res = NextPow2(MathMax(16, resolution));
   double series[];
   ArrayResize(series, res);
   for(int i=0;i<res;i++) series[i]=0.0;
   for(int i=0;i<totalLines;i++)
   {
      double norm = (priceList[i] - minPrice)/range;
      norm = MathMax(0.0, MathMin(1.0, norm));
      int idx = (int)MathRound(norm * (res-1));
      if(idx<0) idx=0;
      if(idx>=res) idx=res-1;
      series[idx] += 1.0;
   }

   double specRe[], specIm[];
   ArrayResize(specRe, res);
   ArrayResize(specIm, res);
   if(!FFT_RealForward(series, res, specRe, specIm))
      return false;

   int nyquist = res/2;
   struct Harmonic { int idx; double amp; };
   Harmonic h[];
   ArrayResize(h,0);
   for(int k=1;k<nyquist;k++)
   {
      double amp = MathSqrt(specRe[k]*specRe[k] + specIm[k]*specIm[k]);
      if(amp < minAmplitude)
         continue;
      int pos = ArraySize(h);
      ArrayResize(h, pos+1);
      h[pos].idx = k;
      h[pos].amp = amp;
   }
   if(ArraySize(h)==0)
      return false;
   for(int a=0;a<ArraySize(h)-1;a++){
      int best=a;
      for(int b=a+1;b<ArraySize(h);b++) if(h[b].amp > h[best].amp) best=b;
      if(best!=a){ Harmonic t=h[a]; h[a]=h[best]; h[best]=t; }
   }
   int selected = MathMin(topHarmonics, ArraySize(h));
   if(selected<=0)
      return false;
   int selectedIdx[];
   ArrayResize(selectedIdx, selected);
   for(int i=0;i<selected;i++) selectedIdx[i]=h[i].idx;

   double recon[];
   ArrayResize(recon, res);
   for(int n=0;n<res;n++)
   {
      double val = specRe[0]/res;
      for(int i=0;i<selected;i++)
      {
         int k = selectedIdx[i];
         double angle = 2.0*M_PI*k*(double)n/(double)res;
         double contrib = (specRe[k]*MathCos(angle) - specIm[k]*MathSin(angle));
         val += (2.0/res) * contrib;
      }
      recon[n]=val;
   }

   double temp[];
   ArrayResize(temp, res);
   ArrayCopy(temp, recon);
   int guard = MathMax(1, res / MathMax(2, levelsToShow*2));

   LegSeg referenceLeg;
   bool hasReference = (leg_count>0);
   if(hasReference)
      referenceLeg = legs[0];

   for(int level=0; level<levelsToShow; level++)
   {
      int bestIdx=-1;
      double bestValue=-1e100;
      for(int i=0;i<res;i++)
      {
         if(temp[i] > bestValue)
         {
            bestValue = temp[i];
            bestIdx = i;
         }
      }
      if(bestIdx<0 || bestValue<=0.0)
         break;
      double norm = (double)bestIdx/(double)(res-1);
      double price = minPrice + norm * range;
      int pidx = ArraySize(outPrices);
      ArrayResize(outPrices, pidx+1);
      ArrayResize(outScores, pidx+1);
      ArrayResize(outRatios, pidx+1);
      ArrayResize(outLineCounts, pidx+1);
      outPrices[pidx] = price;
      outScores[pidx] = bestValue;
      double ratio = -1.0;
      if(hasReference)
         ratio = ComputeRatioFromLeg(referenceLeg, price);
      outRatios[pidx] = ratio;
      int start=MathMax(0, bestIdx-guard);
      int end=MathMin(res-1, bestIdx+guard);

      double lineCount=0.0;
      for(int j=start;j<=end;j++)
         lineCount += (j>=0 && j<ArraySize(series) ? series[j] : 0.0);
      outLineCounts[pidx] = lineCount;

      for(int i=start;i<=end;i++)
         temp[i] = -1e100;
   }

   return (ArraySize(outPrices)>0);
}

bool BuildFFTTimeLevels(const LegSeg &legs[], int leg_count,
                        int windowLegs, int resolution,
                        int topHarmonics, int levelsToShow, double minAmplitude,
                        int chartPeriodSeconds,
                        datetime &outTimes[], double &outScores[], double &outDurBars[])
{
   ArrayResize(outTimes,0);
   ArrayResize(outScores,0);
   ArrayResize(outDurBars,0);
   if(leg_count<=0 || resolution<=0 || topHarmonics<=0 || levelsToShow<=0)
      return false;

   int maxLegId=-1;
   for(int i=0;i<leg_count;i++)
      if(legs[i].id > maxLegId) maxLegId = legs[i].id;
   if(maxLegId<0)
      return false;
   int window = MathMax(1, windowLegs);
   int threshold = MathMax(0, maxLegId - window + 1);

   double durations[];
   ArrayResize(durations, 0);
   double minDur = DBL_MAX, maxDur = -DBL_MAX;
   for(int i=0;i<leg_count;i++)
   {
      if(legs[i].id < threshold) continue;
      long dt = (long)legs[i].t2 - (long)legs[i].t1;
      double seconds = (double)MathAbs(dt);
      if(seconds <= 0.0) continue;
      int idx = ArraySize(durations);
      ArrayResize(durations, idx+1);
      durations[idx] = seconds;
      if(seconds < minDur) minDur = seconds;
      if(seconds > maxDur) maxDur = seconds;
   }
   if(ArraySize(durations)<=0)
      return false;
   double range = maxDur - minDur;
   if(range <= 1.0)
      return false;

   int res = NextPow2(MathMax(16, resolution));
   double series[];
   ArrayResize(series, res);
   for(int i=0;i<res;i++) series[i]=0.0;
   for(int i=0;i<ArraySize(durations);i++)
   {
      double norm = (durations[i] - minDur)/range;
      norm = MathMax(0.0, MathMin(1.0, norm));
      int idx = (int)MathRound(norm * (res-1));
      if(idx<0) idx=0;
      if(idx>=res) idx=res-1;
      series[idx] += 1.0;
   }

   double specRe[], specIm[];
   ArrayResize(specRe, res);
   ArrayResize(specIm, res);
   if(!FFT_RealForward(series, res, specRe, specIm))
      return false;

   int nyquist = res/2;
   struct Harmonic { int idx; double amp; };
   Harmonic h[]; ArrayResize(h,0);
   for(int k=1;k<nyquist;k++)
   {
      double amp = MathSqrt(specRe[k]*specRe[k] + specIm[k]*specIm[k]);
      if(amp < minAmplitude)
         continue;
      int pos = ArraySize(h);
      ArrayResize(h, pos+1);
      h[pos].idx = k;
      h[pos].amp = amp;
   }
   if(ArraySize(h)==0)
      return false;
   for(int a=0;a<ArraySize(h)-1;a++){
      int best=a;
      for(int b=a+1;b<ArraySize(h);b++) if(h[b].amp > h[best].amp) best=b;
      if(best!=a){ Harmonic t=h[a]; h[a]=h[best]; h[best]=t; }
   }
   int selected = MathMin(topHarmonics, ArraySize(h));
   if(selected<=0)
      return false;
   int selectedIdx[];
   ArrayResize(selectedIdx, selected);
   for(int i=0;i<selected;i++) selectedIdx[i]=h[i].idx;

   double recon[];
   ArrayResize(recon, res);
   for(int n=0;n<res;n++)
   {
      double val = specRe[0]/res;
      for(int i=0;i<selected;i++)
      {
         int k = selectedIdx[i];
         double angle = 2.0*M_PI*k*(double)n/(double)res;
         double contrib = (specRe[k]*MathCos(angle) - specIm[k]*MathSin(angle));
         val += (2.0/res) * contrib;
      }
      recon[n]=val;
   }

   double temp[];
   ArrayResize(temp, res);
   ArrayCopy(temp, recon);
   int guard = MathMax(1, res / MathMax(2, levelsToShow*2));
   datetime baseTime = (leg_count>0 ? legs[0].t2 : TimeCurrent());

   for(int level=0; level<levelsToShow; level++)
   {
      int bestIdx=-1;
      double bestValue=-1e100;
      for(int i=0;i<res;i++)
      {
         if(temp[i] > bestValue)
         {
            bestValue = temp[i];
            bestIdx = i;
         }
      }
      if(bestIdx<0 || bestValue<=0.0)
         break;
      double norm = (double)bestIdx/(double)(res-1);
      double durationSec = minDur + norm * range;
      if(durationSec<=0.0)
         continue;

      datetime target = (datetime)((long)baseTime + (long)MathRound(durationSec));
      int idx = ArraySize(outTimes);
      ArrayResize(outTimes, idx+1);
      ArrayResize(outScores, idx+1);
      ArrayResize(outDurBars, idx+1);
      outTimes[idx] = target;
      outScores[idx] = bestValue;
      double ps = (double)MathMax(1, chartPeriodSeconds);
      outDurBars[idx] = durationSec/ps;

      int start=MathMax(0, bestIdx-guard);
      int end=MathMin(res-1, bestIdx+guard);
      for(int i=start;i<=end;i++)
         temp[i] = -1e100;
   }
   return (ArraySize(outTimes)>0);
}

bool BuildKMeansPriceClusters(const FibItem &all[], int all_total,
                              const int &view_idx[], int view_count,
                              int clusterCount, int maxIterations, int minLines,
                              double bandThickness,
                              const double &fibLevels[], int fibCount, double fibTolerance,
                              ClusterResult &outResult,
                              double &clusterCentersOut[], int &clusterCountsOut[], double &clusterRatiosOut[])
{
   outResult.Clear();
   ArrayResize(outResult.member_mask, all_total);
   for(int i=0;i<all_total;i++)
      outResult.member_mask[i]=false;
   ArrayResize(clusterCentersOut, 0);
   ArrayResize(clusterCountsOut, 0);
   ArrayResize(clusterRatiosOut, 0);

   if(view_count<=0 || all_total<=0)
      return false;

   double priceList[];
   int fibIndexList[];
   ArrayResize(priceList, view_count);
   ArrayResize(fibIndexList, view_count);

   int dataCount=0;
   for(int k=0;k<view_count;k++)
   {
      int idx=view_idx[k];
      if(idx<0 || idx>=all_total) continue;
      if(all[idx].kind!=FIBK_PRICE) continue;
      double price=all[idx].price;
      if(!MathIsValidNumber(price)) continue;
      priceList[dataCount]=price;
      fibIndexList[dataCount]=idx;
      dataCount++;
   }

   if(dataCount<=0)
      return false;

   clusterCount = MathMax(1, MathMin(clusterCount, dataCount));
   maxIterations = MathMax(1, maxIterations);
   minLines = MathMax(1, minLines);

   double centroids[];
   ArrayResize(centroids, clusterCount);
   double sorted[];
   ArrayResize(sorted, dataCount);
   for(int i=0;i<dataCount;i++) sorted[i]=priceList[i];
   ArraySort(sorted);

   if(clusterCount==1)
   {
      double sum=0.0;
      for(int i=0;i<dataCount;i++) sum+=priceList[i];
      centroids[0] = (dataCount>0 ? sum/(double)dataCount : sorted[0]);
   }
   else
   {
      int denom = MathMax(1, clusterCount-1);
      for(int c=0;c<clusterCount;c++)
      {
         int pos = (int)MathRound((double)c * (double)(dataCount-1) / (double)denom);
         if(pos<0) pos=0;
         if(pos>=dataCount) pos=dataCount-1;
         centroids[c]=sorted[pos];
      }
   }

   int assignments[];
   ArrayResize(assignments, dataCount);
   for(int i=0;i<dataCount;i++) assignments[i]=-1;

   double accum[];
   ArrayResize(accum, clusterCount);
   int counts[];
   ArrayResize(counts, clusterCount);

   bool changed=true;
   int iter=0;
   while(changed && iter<maxIterations)
   {
      changed=false;
      for(int c=0;c<clusterCount;c++){ counts[c]=0; accum[c]=0.0; }

      for(int p=0;p<dataCount;p++)
      {
         double price = priceList[p];
         int bestIdx=0;
         double bestDist = MathAbs(price - centroids[0]);
         for(int c=1;c<clusterCount;c++)
         {
            double dist = MathAbs(price - centroids[c]);
            if(dist < bestDist)
            {
               bestDist = dist;
               bestIdx = c;
            }
         }
         if(assignments[p]!=bestIdx)
         {
            assignments[p]=bestIdx;
            changed=true;
         }
         counts[bestIdx]++;
         accum[bestIdx]+=price;
      }

      for(int c=0;c<clusterCount;c++)
      {
         if(counts[c]>0)
            centroids[c] = accum[c]/(double)counts[c];
      }

      iter++;
   }

   double tolBase = MathMax(LabelManager::PriceTolerance(), _Point);
   double bandHalfOverride = (bandThickness>0.0 ? MathMax(bandThickness*0.5, tolBase) : 0.0);

   int visible=0;
   outResult.cluster_count = 0;

   for(int c=0;c<clusterCount;c++)
   {
      // build member list
      int memberFib[];
      double memberDist[];
      ArrayResize(memberFib, 0);
      ArrayResize(memberDist, 0);
      for(int p=0;p<dataCount;p++)
      {
         if(assignments[p]!=c) continue;
         int fibIdx = fibIndexList[p];
         if(fibIdx<0 || fibIdx>=all_total) continue;
         double dist = MathAbs(priceList[p] - centroids[c]);
         int m = ArraySize(memberFib);
         ArrayResize(memberFib, m+1);
         ArrayResize(memberDist, m+1);
         memberFib[m]=fibIdx;
         memberDist[m]=dist;
      }
      int memberCount = ArraySize(memberFib);
      if(memberCount < minLines)
         continue;

      for(int a=0;a<memberCount-1;a++)
      {
         int best=a;
         for(int b=a+1;b<memberCount;b++)
            if(memberDist[b] < memberDist[best]) best=b;
         if(best!=a)
         {
            double td = memberDist[a]; memberDist[a]=memberDist[best]; memberDist[best]=td;
            int tf = memberFib[a]; memberFib[a]=memberFib[best]; memberFib[best]=tf;
         }
      }

      int limitIdx = MathMin(minLines-1, memberCount-1);
      double limitDist = memberDist[limitIdx];
      double cutoff = limitDist + tolBase;
      if(bandHalfOverride>0.0)
         cutoff = MathMin(cutoff, bandHalfOverride);
      if(cutoff<=0.0)
         cutoff = tolBase;

      double avgRatio = -1.0;
      if(memberCount>0)
      {
         double ratioSum=0.0;
         int ratioCount=0;
         for(int p=0;p<dataCount;p++)
         {
            if(assignments[p]!=c) continue;
            int fibIdx = fibIndexList[p];
            if(fibIdx<0 || fibIdx>=all_total) continue;
            if(all[fibIdx].ratio>0.0){
               ratioSum += all[fibIdx].ratio;
               ratioCount++;
            }
         }
         if(ratioCount>0)
            avgRatio = ratioSum/(double)ratioCount;
      }

      double snappedRatio = avgRatio;
      if(avgRatio>0.0 && fibCount>0 && fibTolerance>0.0)
      {
         double bestDiff = DBL_MAX;
         double bestRatio = avgRatio;
         for(int f=0;f<fibCount;f++)
         {
            double target = fibLevels[f];
            double diff = MathAbs(target - avgRatio);
            if(diff < bestDiff)
            {
               bestDiff = diff;
               bestRatio = target;
            }
         }
         if(bestDiff <= fibTolerance)
            snappedRatio = bestRatio;
      }

      outResult.cluster_count++;
      int infoIdx = ArraySize(clusterCentersOut);
      ArrayResize(clusterCentersOut, infoIdx+1);
      ArrayResize(clusterCountsOut, infoIdx+1);
      ArrayResize(clusterRatiosOut, infoIdx+1);
      clusterCentersOut[infoIdx] = centroids[c];
      clusterCountsOut[infoIdx] = memberCount;
      clusterRatiosOut[infoIdx] = snappedRatio;

      for(int i=0;i<memberCount;i++)
      {
         if(memberDist[i] > cutoff)
            continue;
         int fibIdx = memberFib[i];
         if(fibIdx<0 || fibIdx>=all_total) continue;
         if(!outResult.member_mask[fibIdx])
         {
            outResult.member_mask[fibIdx]=true;
            visible++;
         }
      }
   }

   outResult.visible_candidates = visible;
   return (visible>0);
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
      Dbg(StringFormat("Leg %d: A(idx=%d time=%s price=%g high=%s) B(idx=%d time=%s price=%g high=%s)",
                       built, pA.index, TimeToString(pA.time), pA.price, pA.is_high ? "topo":"fundo",
                       pB.index, TimeToString(pB.time), pB.price, pB.is_high ? "topo":"fundo"));

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
   ConfigureRatioColorsFromInput();
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
   PricePipelineResult pricePipeline = g_pivot_pipeline.Result();

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
   bool usingKMeans = (InpPriceMode==PRICE_KMEANS);
   bool usingFFT = (InpPriceMode==PRICE_FFT);
   if(!usingKMeans)
      ClearKMeansLabels();
   if(!usingFFT){
      ClearFFTLabels();
      ClearFFTLines();
   }

   if(InpPriceMode==PRICE_RAW)
   {
      g_ctx.visible_cluster_lines = g_renderer.RenderPriceRaw(g_ctx.all, g_ctx.all_total,
                                                              g_ctx.view_price, g_label_manager);
      g_ctx.cluster_group_count = 0;
   }
   else if(InpPriceMode==PRICE_KMEANS)
   {
      double kmBandRange = 0.0;
      if(InpKMeansBandPctATR>0.0)
      {
         double kmAtr=0.0; bool kmAtrOk = GetATR_D1(InpATR_D1_Periods, kmAtr);
         if(!kmAtrOk || kmAtr<=0.0){
            double sumR=0.0; int N=MathMin(200,rates_total);
            for(int i=0;i<N;i++) sumR += (high[i]-low[i]);
            kmAtr = (N>0? sumR/N : 0.0);
         }
         kmBandRange = kmAtr * (InpKMeansBandPctATR/100.0);
      }

      ClusterResult kmRes;
      double kmCenters[];
      int kmCounts[];
      double kmRatios[];
      bool okKM = BuildKMeansPriceClusters(g_ctx.all, g_ctx.all_total,
                                           g_ctx.view_price, ArraySize(g_ctx.view_price),
                                           InpKMeansClusterCount,
                                           InpKMeansMaxIterations,
                                           InpKMeansMinLines,
                                           kmBandRange,
                                           g_ctx.fib_ratios, ArraySize(g_ctx.fib_ratios),
                                           InpKMeansFibSnapTolerance,
                                           kmRes,
                                           kmCenters, kmCounts, kmRatios);
      if(okKM)
      {
         g_ctx.cluster_group_count = kmRes.cluster_count;
         g_ctx.visible_cluster_lines = g_renderer.RenderPriceClusters(g_ctx.all, g_ctx.all_total,
                                                                      g_ctx.view_price,
                                                                      kmRes,
                                                                      g_label_manager);
         if(InpDebugLog){
            Dbg(StringFormat("[Fibo][%s] KMeans k=%d iter=%d minLines=%d  Band=%s%% ATR  Clusters=%d  Lines=%d  Total=%d",
                  _Symbol,
                  InpKMeansClusterCount, InpKMeansMaxIterations, InpKMeansMinLines,
                  FiboUtils::FormatPercentValue(InpKMeansBandPctATR),
                  g_ctx.cluster_group_count, g_ctx.visible_cluster_lines, ArraySize(g_ctx.view_price)));
         }
         RenderKMeansClusterLabels(kmCenters, kmCounts, kmRatios, ArraySize(kmCenters),
                                   g_renderer.CurrentLabelRight());
      }
      else
      {
         g_ctx.cluster_group_count = 0;
         g_ctx.visible_cluster_lines = 0;
         g_overlay.ClearTrackedPriceLines();
         ClearKMeansLabels();
      }
   }
   else if(InpPriceMode==PRICE_FFT)
   {
      double fftPrices[];
      double fftScores[];
      double fftRatios[];
      double fftLineCounts[];
      bool okFFT = BuildFFTPriceLevels(g_ctx.all, g_ctx.all_total,
                                       g_ctx.view_price, ArraySize(g_ctx.view_price),
                                       pricePipeline.legs, pricePipeline.leg_count,
                                       InpFFTWindowLegs, InpFFTResolution,
                                       InpFFTTopHarmonics, InpFFTLevelsToShow,
                                       InpFFTMinAmplitude,
                                       fftPrices, fftScores, fftRatios, fftLineCounts);
      g_overlay.ClearTrackedPriceLines();
      ClearFFTLines();
      if(okFFT)
      {
         g_ctx.cluster_group_count = ArraySize(fftPrices);
         int lineWidth = MathMax(1, InpFibLineWidth);
         for(int i=0;i<g_ctx.cluster_group_count;i++)
         {
            string name = G_PREF_FFT_LINE + IntegerToString(i);
            g_overlay.UpsertPriceSegment(name, 0, 0, fftPrices[i], InpFFTLineColor, lineWidth);
            g_overlay.RecordPriceLineName(name);
         }
         g_ctx.prev_fft_line_count = g_ctx.cluster_group_count;
         g_ctx.visible_cluster_lines = g_ctx.cluster_group_count;
         RenderFFTLabels(fftPrices, fftScores, fftRatios, fftLineCounts,
                         ArraySize(fftPrices),
                         g_renderer.CurrentLabelRight());
      }
      else
      {
         g_ctx.cluster_group_count = 0;
         g_ctx.visible_cluster_lines = 0;
         ClearFFTLabels();
         ClearFFTLines();
      }
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
      ClusterResult clusterRes = g_cluster_manager.Result();

      g_ctx.cluster_group_count = clusterRes.cluster_count;

      g_ctx.visible_cluster_lines = g_renderer.RenderPriceClusters(g_ctx.all, g_ctx.all_total,
                                                                   g_ctx.view_price,
                                                                   clusterRes,
                                                                   g_label_manager);

      if(InpDebugLog){
         Dbg(StringFormat("[Fibo][%s] Src=ZZ  ATR(1D,p=%d)=%s  Range=%s%%  MinLines=%d  Clusters=%d  ClusterLines=%d  LinesTot=%d",
               _Symbol,
               InpATR_D1_Periods, FiboUtils::FormatPrice(atrD1), FiboUtils::FormatPercentValue(InpClusterRangePctATR),
               InpClusterMinLines,
               g_ctx.cluster_group_count, g_ctx.visible_cluster_lines, ArraySize(g_ctx.view_price)));
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

   // FFT temporal
   if(InpEnableFFTTime)
   {
      double fftTimes[];
      double fftScores[];
      double fftDurBars[];
      int ps = PeriodSeconds(); if(ps<=0) ps=60;
      bool okTimeFFT = BuildFFTTimeLevels(pricePipeline.legs, pricePipeline.leg_count,
                                          InpFFTTimeWindowLegs, InpFFTTimeResolution,
                                          InpFFTTimeTopHarmonics, InpFFTTimeLevelsToShow,
                                          InpFFTTimeMinAmplitude, ps,
                                          fftTimes, fftScores, fftDurBars);
      ClearFFTTimeLines();
      if(okTimeFFT)
      {
         int lines = ArraySize(fftTimes);
         g_ctx.prev_fft_time_line_count = lines;
         for(int i=0;i<lines;i++)
         {
            string name = G_PREF_FFT_TIME_LINE + IntegerToString(i);
            g_overlay.UpsertVLine(name, fftTimes[i], InpFFTTimeColor, 1, true);
         }
         double priceBase = (pricePipeline.leg_count>0 ? pricePipeline.legs[0].p2 : close[0]);
         RenderFFTTimeLabels(fftTimes, fftScores, fftDurBars, lines, priceBase);
      }
      else
      {
         ClearFFTTimeLabels();
      }
   }
   else
   {
      ClearFFTTimeLines();
      ClearFFTTimeLabels();
   }

   // 6) RESUMO (visor)
   if(InpShowSummary)
   {
      string ln1;
      if(InpPriceMode==PRICE_CLUSTER)
      {
         ln1 = StringFormat(
            "PRICE  Linhas:%d  EmCluster:%d  Clusters:%d  Range=%s%% ATR(1D,p=%d)",
            ArraySize(g_ctx.view_price), g_ctx.visible_cluster_lines, g_ctx.cluster_group_count,
            FiboUtils::FormatPercentValue(InpClusterRangePctATR), InpATR_D1_Periods
         );
      }
      else if(InpPriceMode==PRICE_KMEANS)
      {
         ln1 = StringFormat(
            "PRICE  Linhas:%d  EmKMeans:%d  Clusters:%d  K=%d  Iter=%d  Band=%s%% ATR",
            ArraySize(g_ctx.view_price), g_ctx.visible_cluster_lines, g_ctx.cluster_group_count,
            InpKMeansClusterCount, InpKMeansMaxIterations,
            FiboUtils::FormatPercentValue(InpKMeansBandPctATR)
         );
      }
      else if(InpPriceMode==PRICE_FFT)
      {
         ln1 = StringFormat(
            "PRICE  Linhas:%d  FFTNíveis:%d  Harmônicos:%d  Resol=%d",
            ArraySize(g_ctx.view_price), g_ctx.cluster_group_count,
            InpFFTTopHarmonics, InpFFTResolution
         );
      }
      else
      {
         ln1 = StringFormat("PRICE  Linhas:%d  Modo RAW (clusters desligados)", ArraySize(g_ctx.view_price));
      }

      string ln2;
      if(InpPriceMode==PRICE_CLUSTER)
      {
         ln2 = StringFormat("PRICE  R:%d  X:%d  MinLinhas:%d  Pernas:%d  Topos:%d  Fundos:%d",
                            g_ctx.retrace_total, g_ctx.expansion_total, InpClusterMinLines,
                            g_ctx.leg_total, g_ctx.pivot_tops, g_ctx.pivot_bottoms);
      }
      else if(InpPriceMode==PRICE_KMEANS)
      {
         ln2 = StringFormat("PRICE  R:%d  X:%d  MinK:%d  Pernas:%d  Topos:%d  Fundos:%d",
                            g_ctx.retrace_total, g_ctx.expansion_total, InpKMeansMinLines,
                            g_ctx.leg_total, g_ctx.pivot_tops, g_ctx.pivot_bottoms);
      }
      else if(InpPriceMode==PRICE_FFT)
      {
         ln2 = StringFormat("PRICE  R:%d  X:%d  FFTLegs:%d  Níveis:%d  Harmônicos:%d",
                            g_ctx.retrace_total, g_ctx.expansion_total,
                            InpFFTWindowLegs, InpFFTLevelsToShow, InpFFTTopHarmonics);
      }
      else
      {
         ln2 = StringFormat("PRICE  R:%d  X:%d  Pernas:%d  Topos:%d  Fundos:%d",
                            g_ctx.retrace_total, g_ctx.expansion_total,
                            g_ctx.leg_total, g_ctx.pivot_tops, g_ctx.pivot_bottoms);
      }
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
