// Pivot pipeline definitions

struct PipelineConfig
{
   int pivot_lookback;
   int trim_recent_segments;
   int legs_to_use;

   PipelineConfig()
   {
      pivot_lookback = 0;
      trim_recent_segments = 0;
      legs_to_use = 0;
   }
};

struct PricePipelineResult {
   Pivot    pivots[];
   int      pivot_count;
   LegSeg   legs[];
   int      leg_count;
   LineItem price_lines[];
   int      price_count;

   void Clear()
   {
      pivot_count = 0;
      leg_count = 0;
      price_count = 0;
      ArrayResize(pivots, 0);
      ArrayResize(legs, 0);
      ArrayResize(price_lines, 0);
   }
};

class PivotPipeline
{
private:
   PipelineConfig     m_cfg;
   PricePipelineResult m_result;

   bool BuildPricePipeline(const double &high[], const double &low[], const datetime &time[],
                           int rates_total,
                           Pivot &out_pivots[], int &out_pivot_count,
                           LegSeg &out_legs[], int &out_leg_count,
                           LineItem &out_price_lines[], int &out_price_count)
   {
      const int clampTrim = MathMax(0, m_cfg.trim_recent_segments);
      out_pivot_count = CollectPivots_ZZ(high, low, time, rates_total, m_cfg.pivot_lookback, out_pivots);
      out_pivot_count = TrimRecentPivotSegments(out_pivots, clampTrim);

      BuildLegsFromPivots(out_pivots, out_pivot_count, m_cfg.legs_to_use, out_legs, out_leg_count);
      BuildAllPriceLines(out_legs, out_leg_count, out_price_lines, out_price_count);

      bool havePivots = (out_pivot_count >= 2);
      bool haveLegs   = (out_leg_count   > 0);
      bool haveLines  = (out_price_count > 0);
      return (havePivots && haveLegs && haveLines);
   }

public:
   PivotPipeline(){ m_cfg = PipelineConfig(); m_result.Clear(); }

   void Configure(const PipelineConfig &cfg){ m_cfg = cfg; }

   bool Build(const double &high[], const double &low[], const datetime &time[], int rates_total)
   {
      m_result.Clear();
      return BuildPricePipeline(high, low, time, rates_total,
                                m_result.pivots, m_result.pivot_count,
                                m_result.legs, m_result.leg_count,
                                m_result.price_lines, m_result.price_count);
   }

   const PricePipelineResult& Result() const { return m_result; }
};
