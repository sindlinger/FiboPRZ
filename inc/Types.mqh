// Core types and enums used across modules

// Enums used by inputs and modules
enum ENUM_PRICE_MODE { PRICE_CLUSTER=0, PRICE_RAW=1, PRICE_KMEANS=2, PRICE_FFT=3 };
enum ENUM_LABEL_DISPLAY_MODE { LABEL_MODE_NORMAL=0, LABEL_MODE_DEBUG=1, LABEL_MODE_TRADING=2 };
enum ENUM_PRICE_LINE_TRIM_MODE { PRICE_LINE_TRIM_OLDEST=0, PRICE_LINE_TRIM_FARTHEST=1 };
enum ENUM_FIB_KIND { FIBK_PRICE=0, FIBK_TIME=1 };

// Basic data structures
struct Pivot { double price; datetime time; bool is_high; int index; };
struct LegSeg {
   double p1,p2;
   datetime t1,t2;
   bool is_up;
   int id;
   bool a_is_high;
   bool b_is_high;
   int idx_a;
   int idx_b;
};

struct LineItem { double price; double ratio; bool is_expansion; bool is_up; int leg_id; datetime tB; };
// Time carries price of pivot B to render at same level
struct TimeItem { datetime t; double ratio; int leg_id; bool forward; double priceB; };

struct FibItem {
   ENUM_FIB_KIND kind;
   double   ratio;
   int      leg_id;
   // price
   double   price; bool is_expansion; bool is_up; datetime tB;
   // time
   datetime t; bool forward;
};

struct RatioColorRule
{
   double ratio;
   color  retrace_color;
   color  expansion_color;
   bool   has_retrace;
   bool   has_expansion;

   RatioColorRule()
   {
      ratio = 0.0;
      retrace_color = clrNONE;
      expansion_color = clrNONE;
      has_retrace = false;
      has_expansion = false;
   }
};

struct ClusterLegPick { int leg_id; int fib_idx; double dist_center; };

// Visualization options for legs
struct VisualConfig
{
   bool show_legs;
   color leg_up_color;
   color leg_down_color;
   int leg_width;
   int right_text_margin_bars;

   VisualConfig()
   {
      show_legs = true;
      leg_up_color = clrLime;
      leg_down_color = clrOrange;
      leg_width = 1;
      right_text_margin_bars = 0;
   }
};

// Global analysis context
struct FiboContext
{
   double fib_ratios[];
   double time_ratios[];
   string price_line_names[];

   int prev_leg_count;
   int prev_tf_count;
   int prev_tfvl_count;
   int prev_zz1_count;
   int prev_zz2_count;
   int prev_zz1_piv_count;
   int prev_zz2_piv_count;
   int prev_dbg_ret_count;
   int prev_dbg_exp_count;
   int prev_dbg_time_dot_count;
   int prev_dbg_time_vl_count;

   int dbg_prints;
   int price_digits;
   ENUM_LABEL_DISPLAY_MODE prev_label_mode;

   LineItem price_all[];
   int price_total;

   TimeItem time_all[];
   int time_total;

   FibItem all[];
   int all_total;
   int view_price[];
   int view_time[];

   int retrace_total;
   int expansion_total;
   int visible_cluster_lines;
   int cluster_group_count;
   int prev_kmeans_label_count;
   int prev_fft_label_count;
   int prev_fft_line_count;
   int pivot_total;
   int pivot_tops;
   int pivot_bottoms;
   int leg_total;

   int zz_handle;
   int zz2_handle;

   string label_slot_identity[];
   bool   label_slot_used[];
   RatioColorRule ratio_color_rules[];
   bool   ratio_color_enabled;

   void Reset()
   {
      ArrayResize(fib_ratios, 0);
      ArrayResize(time_ratios, 0);
      ArrayResize(price_line_names, 0);

      prev_leg_count = 0;
      prev_tf_count = 0;
      prev_tfvl_count = 0;
      prev_zz1_count = 0;
      prev_zz2_count = 0;
      prev_zz1_piv_count = 0;
      prev_zz2_piv_count = 0;
      prev_dbg_ret_count = 0;
      prev_dbg_exp_count = 0;
      prev_dbg_time_dot_count = 0;
      prev_dbg_time_vl_count = 0;

      dbg_prints = 0;
      price_digits = -1;
      prev_label_mode = LABEL_MODE_NORMAL;

      ArrayResize(price_all, 0);
      price_total = 0;
      ArrayResize(time_all, 0);
      time_total = 0;
      ArrayResize(all, 0);
      all_total = 0;
      ArrayResize(view_price, 0);
      ArrayResize(view_time, 0);

      retrace_total = 0;
      expansion_total = 0;
      visible_cluster_lines = 0;
      cluster_group_count = 0;
      prev_kmeans_label_count = 0;
      prev_fft_label_count = 0;
      prev_fft_line_count = 0;
      pivot_total = 0;
      pivot_tops = 0;
      pivot_bottoms = 0;
      leg_total = 0;

      zz_handle = INVALID_HANDLE;
      zz2_handle = INVALID_HANDLE;

      ArrayResize(label_slot_identity, 0);
      ArrayResize(label_slot_used, 0);
      ArrayResize(ratio_color_rules, 0);
      ratio_color_enabled = false;
   }
};
