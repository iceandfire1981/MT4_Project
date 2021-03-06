//+------------------------------------------------------------------+
//|                                                 TakeProfit_1.mq4 |
//|                                        Copyright 2018, FRT Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FRT Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input string input_as_m = "USOIL";   //主资产
input string input_as_s = "UKOIL";   //次资产
input int    input_bar_count = 180;  //行情数量(3小时，1分钟线)
input int    input_begin_bar_index = 30; //计算开始索引（最近半小时）
input double input_sl   = 0.2;       //止损差价
input double input_tp   = 0.6;       //止盈差价
input double input_x    = 0.15;      //偏移价差
input double input_adjust = 0.05;    //修正值
input int    input_slip   = 1.0;     //滑点值
input double input_shares_m = 0.1;     //主执行数量
input double input_shares_s = 0.1;     //次执行数量

class CIsNewBar 
{
 private:
   string   mSymbol;
   datetime mOldDatetime;
   ENUM_TIMEFRAMES mTimeFrames;
 
 public:
   CIsNewBar(string input_symbol){
      mSymbol = input_symbol;
      mOldDatetime = -1; 
      mTimeFrames = PERIOD_M1;
   };
   
   bool isNewBar(){
      datetime new_datetime = datetime(SeriesInfoInteger(mSymbol, mTimeFrames, SERIES_LASTBAR_DATE));
      if ( new_datetime != mOldDatetime && new_datetime ){
         mOldDatetime = new_datetime;
         return(true);
      } else{
         return(false);
      }
   };
   
   void changeTimeFrame(ENUM_TIMEFRAMES input_timeframe) {
      mTimeFrames = input_timeframe;
      mOldDatetime = -1;
   }
};

CIsNewBar* mCurrentTool;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   mCurrentTool = new CIsNewBar(input_as_m);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    MqlRates usoil_rates[];
    MqlRates ukoil_rates[];
    ArraySetAsSeries(usoil_rates, true);
    ArraySetAsSeries(ukoil_rates, true); 
    
    int usoil_copied = CopyRates(input_as_m, PERIOD_M1, 0, input_bar_count, usoil_rates);
    int ukoil_copied = CopyRates(input_as_s, PERIOD_M1, 0, input_bar_count, ukoil_rates);
    bool is_new_bar = mCurrentTool.isNewBar();
    
    double difx[];
    ArrayResize(difx, input_bar_count, 0);
    for(int bar_index = 0; bar_index < input_bar_count; bar_index++){
       difx[bar_index] = ukoil_rates[bar_index].high - usoil_rates[bar_index].high;
    }
   
    double difx_max = -1000.0;
    double difx_min = 1000.0;
   
    for(int loop_index = input_begin_bar_index; loop_index < input_bar_count; loop_index++){
      PrintFormat("OnTick::current= %.4f, max= %.4f, min= %.4f", difx[loop_index], difx_max, difx_min);
      if(difx_max < difx[loop_index]) {
         difx_max = difx[loop_index];
      }
      
      if(difx_min > difx[loop_index]) {
         difx_min = difx[loop_index];
      }
    }
    
    bool has_order = hasOrder();
    
    double dift = ukoil_rates[0].high - usoil_rates[0].high;
    double usoil_ask = MarketInfo(input_as_m, MODE_ASK);
    double ukoil_bid = MarketInfo(input_as_s, MODE_BID);
    
    PrintFormat("OnTicket::output_info::usb= %d, ukb= %d, new_bar= %d, max= %.3f, min= %.3f, t= %.3f, has_order= %d, us_ask= %.5f, uk_bid= %.5f",
                                        usoil_copied, ukoil_copied, is_new_bar, difx_max, difx_min, dift, has_order, usoil_ask, ukoil_bid);
    
    if(has_order == false){
       if(is_new_bar == true){
         if((difx_max - difx_min) >= input_tp && 
            ((difx_min < dift) && (dift < (difx_min + input_x)))) {
            /*OrderSend(input_as_m, OP_SELL, input_shares_m, usoil_ask, 
               input_slip, (usoil_ask + input_sl), (usoil_ask - input_tp), "y1", clrAliceBlue);
            OrderSend(input_as_s, OP_BUY, input_shares_s, ukoil_bid, 
               input_slip, (ukoil_bid - input_sl), (ukoil_bid + input_tp), "y2", clrAliceBlue);*/
         }
       }
    } else {
       if(((difx_max - difx_min)/2 - input_adjust) <= difx[0] && 
          ((difx_max - difx_min)/2 + input_adjust) >= difx[0]){
         //closeMyOrder();
       }
    }
  }
//+------------------------------------------------------------------+

//判断是否有交易记录
bool hasOrder()
{
  int orders_count = OrdersTotal();
  bool is_targeted = false;
  PrintFormat("hasOrder::order_count= %d", orders_count);
  for(int order_index = 0; order_index < orders_count; order_index++)
  {
    if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true){
      OrderPrint();
      string order_comment = StringSubstr(OrderComment(), 0, 1);
      PrintFormat("hasOrder::orderx= %d, comm= %s, comm1= %s", order_index, OrderComment(), order_comment);
      if (StringCompare(order_comment, "Y") == 0 || StringCompare(order_comment, "y") == 0){
        is_targeted = true;
        break;
      }
    } else {
      PrintFormat("Order select %d false=====", order_index);
    }
  };
  return(is_targeted);
};

void closeMyOrder()
{
   int orders_count = OrdersTotal();
   for(int order_index = 0; order_index < orders_count; order_index++){
      if(OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true) {
         OrderPrint();
         string order_comm = OrderComment();
         if(StringCompare(order_comm, "y1")) {
            OrderClose(OrderTicket(), OrderLots(), MarketInfo(input_as_m, MODE_BID), 0, clrAntiqueWhite);
         } else if(StringCompare(order_comm, "y2")){
            OrderClose(OrderTicket(), OrderLots(), MarketInfo(input_as_s, MODE_ASK), 0, clrAntiqueWhite);
         }
      }
   }
};

