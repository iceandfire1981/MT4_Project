//+------------------------------------------------------------------+
//|                                                 TakeProfit_1.mq4 |
//|                                        Copyright 2018, FRT Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FRT Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

input int    input_bar_count       = 1440;        //行情数量(3小时，1分钟线)
input int    input_begin_bar_index = 30;          //计算开始索引（最近半小时）
input int    input_slip            = 2.0;         //滑点值
input int    input_timer_settings  = 10;          //定时器设置（单位：秒）
input double input_sl              = 0.2;         //止损差价
input double input_tp              = 0.6;         //止盈差价
input double input_x               = 0.15;        //偏移价差
input double input_adjust          = 0.05;        //修正值
input double input_shares_m        = 0.1;         //主执行数量
input double input_shares_s        = 0.1;         //次执行数量
input string input_as_m            = "USOIL";     //主资产
input string input_as_s            = "UKOIL";     //次资产
input string input_order_prefix    = "aa";        //订单以及文件前缀


double order_difx_max = 0;   //下单时的最大偏差，止损用
double order_difx_min = 0 ;   //下单时的最小偏差，止损用
int temp_magic_min;  //将最大偏差保存到订单中用
int temp_magic_max;  //将最小偏差保存到订单中用

string order_common_1;
string order_common_2;
string order_common_3;
string order_common_4;
string record_file_name;

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
int OnInit(){
     mCurrentTool = new CIsNewBar(input_as_m);
     
     order_common_1 = input_order_prefix + IntegerToString(input_bar_count) + "_1";
     order_common_2 = input_order_prefix + IntegerToString(input_bar_count) + "_2";
     order_common_3 = input_order_prefix + IntegerToString(input_bar_count) + "_3";
     order_common_4 = input_order_prefix + IntegerToString(input_bar_count) + "_4";
     record_file_name = input_order_prefix + "_" + IntegerToString(input_bar_count) + "_order_file.txt";
     
     EventSetTimer(input_timer_settings);
     return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason){
     EventKillTimer();   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){
}

void OnTimer(){
     if(isTradeTime() == true) {
          MqlRates usoil_rates[];
          ArraySetAsSeries(usoil_rates, true);
          int usoil_copied = CopyRates(input_as_m, PERIOD_M5, 0, input_bar_count, usoil_rates);
          MqlRates ukoil_rates[];
          ArraySetAsSeries(ukoil_rates, true);
          int ukoil_copied = CopyRates(input_as_m, PERIOD_M5, 0, 1, ukoil_rates);
          bool is_new_bar = mCurrentTool.isNewBar();
          bool has_order = hasOrder();
          PrintFormat("OnTick::Pre_info::usoil_bar_count= %d, ukoil_bar_count= %d, is_new_bar= %d", usoil_copied, ukoil_copied, is_new_bar);
          
          double dift = ukoil_rates[0].high - usoil_rates[0].high;
          double usoil_ask = MarketInfo(input_as_m, MODE_ASK);
          double usoil_bid = MarketInfo(input_as_m, MODE_BID);
          double ukoil_ask = MarketInfo(input_as_s, MODE_ASK);
          double ukoil_bid = MarketInfo(input_as_s, MODE_BID);
          PrintFormat("OnTick::Pre_info::usoil_bar_count= %d, ukoil_bar_count= %d, is_new_bar= %d", usoil_copied, ukoil_copied, is_new_bar);
          
          double difx[];
          ArrayResize(difx, input_bar_count, 0);
          for(int bar_index = 0; bar_index < input_bar_count; bar_index++){
               MqlRates ukoil_rates_temp[];
               ArraySetAsSeries(ukoil_rates_temp, true);
               datetime bar_datetime = usoil_rates[bar_index].time;
               int ukoil_copied_temp = CopyRates(input_as_s, PERIOD_M5, bar_datetime, 1, ukoil_rates_temp);
               difx[bar_index] = ukoil_rates_temp[0].high - usoil_rates[bar_index].high;
               ArrayFree(ukoil_rates_temp);    
          }
          
          double difx_max = -1000.0;   
          double difx_min = 1000.0;
          for(int loop_index = input_begin_bar_index; loop_index < input_bar_count; loop_index++){
               if(difx_max < difx[loop_index]) {
                    difx_max = difx[loop_index];
               }
           
               if(difx_min > difx[loop_index]) {
                    difx_min = difx[loop_index];
               }
          }
          PrintFormat("OnTick::Pre_info::difx_min= %.5f, difx_min= %.5f", difx_max, difx_min);
          
          if(has_order == false) {
               if(is_new_bar == true) {
                    temp_magic_min=int (difx_min*100);
                    temp_magic_max=int (difx_max*100);
                    PrintFormat("temp_magic_max=%d, temp_magic_min=%d", temp_magic_max, temp_magic_min);
                    
                    if((difx_max - difx_min) >= input_tp && 
                      ((difx_min < dift) && (dift < (difx_min + input_x)))) {
                         PrintFormat("OnTicket::sendorder min");
                         OrderSend(input_as_m, OP_SELL, input_shares_m, usoil_ask, input_slip, 0, 0, 
                              order_common_1, temp_magic_min,0, clrAliceBlue);
                         writeRecord(input_as_m, difx_max, difx_min, dift, usoil_ask, "SELL", order_common_1);
                         
                         OrderSend(input_as_s, OP_BUY, input_shares_s, ukoil_bid, input_slip, 0, 0, 
                              order_common_2,temp_magic_max,0, clrAliceBlue);
                         writeRecord(input_as_s, difx_max, difx_min, dift, ukoil_bid, "BUY", order_common_2);
                         
                    } else if ((difx_max - difx_min) >= input_tp && 
                      ((difx_max-input_x <= dift) && (dift < difx_max))) {
                         PrintFormat("OnTicket::sendorder max");
                         OrderSend(input_as_m, OP_BUY, input_shares_m, usoil_bid, input_slip, 0, 0, 
                              order_common_3, temp_magic_min,0, clrAliceBlue);
                         writeRecord(input_as_m, difx_max, difx_min, dift, usoil_bid, "BUY", order_common_3);     
                         
                         OrderSend(input_as_s, OP_SELL, input_shares_s, ukoil_ask, input_slip, 0, 0, 
                              order_common_4, temp_magic_max,0, clrAliceBlue);
                         writeRecord(input_as_s, difx_max, difx_min, dift, ukoil_ask, "SELL", order_common_4);     
                    }                                      
               }
          }  else {
             if(((order_difx_max - order_difx_min)/2 - input_adjust) <= difx[0] && 
                 ((order_difx_max - order_difx_min)/2 + input_adjust) >= difx[0]){
                 PrintFormat("win::order_difx_max=%.3f,order_difx_min=%.3f",order_difx_max,order_difx_min);
                 closeMyOrder();
             } else if ( difx[0] >= (order_difx_max + input_sl) || difx[0] <=(order_difx_min -input_sl)){
                 PrintFormat("fail::order_difx_max=%.3f,order_difx_min=%.3f",order_difx_max,order_difx_min);
                 closeMyOrder();
             }
         }
     } else {
          PrintFormat("OnTick::info::Not in trade Time::current time is: %s", TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS));
     }
}

void writeRecord(string write_symbol, double max, double min, double dift, 
          double current_price, string op_str, string common){
     int file_handle = FileOpen(record_file_name, FILE_READ|FILE_WRITE|FILE_TXT);
     if(file_handle != INVALID_HANDLE) {
          FileSeek(file_handle, 0, SEEK_END);
          string write_record = write_symbol + "|" + op_str + "|" + DoubleToStr(max, 5) + "|";
          write_record = write_record + DoubleToStr(min, 5) + "|" + DoubleToStr(dift, 5) + "|";
          write_record = write_record + DoubleToStr(current_price, 5) + "|" + op_str + "|" + common + "|";
          write_record = write_record + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
          FileWriteString(file_handle, write_record);
     }
     FileClose(file_handle);
}

//+------------------------------------------------------------------+
//判断是否有订单，并且更新变量
bool hasOrder(){
    int orders_count = OrdersTotal();
    bool is_targeted = false;
    PrintFormat("hasOrder::order_count= %d", orders_count);
    for(int order_index = 0; order_index < orders_count; order_index++) {
        if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true){
            string orde_temp = OrderComment();
            OrderPrint();
            if(StringCompare(orde_temp, order_common_1) == 0)  {
                PrintFormat("hasOrder1::comm= %s, MagicNumber= %.3f", OrderComment(),OrderMagicNumber());
                order_difx_min=OrderMagicNumber()/100.00;
                is_targeted = true;
                PrintFormat("order_difx_min=%.3f",order_difx_min); 
            } else if(StringCompare(orde_temp, order_common_2) == 0) {
                PrintFormat("hasOrder2::comm= %s, MagicNumber= %.3f", OrderComment(),OrderMagicNumber());
                order_difx_max=OrderMagicNumber()/100.00; 
                is_targeted = true;
                PrintFormat("order_difx_max=%.3f",order_difx_max); 
            } else if(StringCompare(orde_temp, order_common_3) == 0) {
                PrintFormat("hasOrder3::comm= %s, MagicNumber= %.3f", OrderComment(),OrderMagicNumber());
                order_difx_min=OrderMagicNumber()/100.00;
                is_targeted = true;
                PrintFormat("order_difx_min=%.3f",order_difx_min);
            } else if(StringCompare(orde_temp, order_common_4) == 0) {
                PrintFormat("hasOrder4::comm= %s, MagicNumber= %.3f", OrderComment(),OrderMagicNumber());
                order_difx_max=OrderMagicNumber()/100.00;
                is_targeted = true;
                PrintFormat("order_difx_max=%.3f",order_difx_max); 
            }
            PrintFormat("hasOrder::max =%.5f, min= %.5f", order_difx_max, order_difx_min);
        } else {
            PrintFormat("Order select %d false=====", order_index);
        }    
  } 
  return(is_targeted);
};

//判断是否有交易记录
bool hasMyOrder(){
  int orders_count = OrdersTotal();
  bool is_targeted = false;
  PrintFormat("hasMyOrder::order_count= %d", orders_count);
  for(int order_index = 0; order_index < orders_count; order_index++){
    if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true){
          OrderPrint();
          string order_comment = StringSubstr(OrderComment(), 0, 1);
          if (StringCompare(order_comment, order_common_1) == 0 || StringCompare(order_comment, order_common_2) == 0 ||
               StringCompare(order_comment, order_common_3) == 0 || StringCompare(order_comment, order_common_4) == 0){
             is_targeted = true;
             break;
          }
      } else {
          PrintFormat("Order select %d false=====", order_index);
      }
      
    } 
  
  return(is_targeted);
};

void closeMyOrder(){
     if (isTradeTime() == true){
         int orders_count = OrdersTotal();
         PrintFormat("closeMyOrder::info::count= %d", orders_count);
        
         while(OrdersTotal() > 0 && hasMyOrder() == true){
             int orders_count = OrdersTotal();
             bool order_selected = OrderSelect(0, SELECT_BY_POS, MODE_TRADES);
             PrintFormat("closeMyOrder::info::count= %d, result= %d", orders_count, order_selected);
             
             if(order_selected == true) {
                 string order_comm = OrderComment();
                 if(StringCompare(order_comm, order_common_1) == 0) {
                     PrintFormat("closeMyOrder::close y1");
                     OrderClose(OrderTicket(), OrderLots(), MarketInfo(input_as_m, MODE_BID), 0, clrAntiqueWhite);
                 } else if(StringCompare(order_comm, order_common_2) == 0){
                     PrintFormat("closeMyOrder::close y2");
                     OrderClose(OrderTicket(), OrderLots(), MarketInfo(input_as_s, MODE_ASK), 0, clrAntiqueWhite);
                 } else if(StringCompare(order_comm, order_common_3) == 0){
                     PrintFormat("closeMyOrder::close y3");
                     OrderClose(OrderTicket(), OrderLots(), MarketInfo(input_as_m, MODE_ASK), 0, clrAntiqueWhite);
                 } else if(StringCompare(order_comm, order_common_4) == 0){
                     PrintFormat("closeMyOrder::close y4");
                     OrderClose(OrderTicket(), OrderLots(), MarketInfo(input_as_s, MODE_BID), 0, clrAntiqueWhite);
                 }
             } else {
                 PrintFormat("closeMyOrder::error::code= %d", GetLastError());
             }
         }
     }
};

//定义交易时段
bool isTradeTime(){
     datetime local_time = TimeCurrent() + 28798;//加上时差
     string date_str = TimeToStr(local_time, TIME_DATE);
     
     datetime us_time_begin_1 = StringToTime(date_str + " 08:10:00");
     datetime us_time_end_1   = StringToTime(date_str + " 23:59:00");
     
     datetime us_time_begin_2 = StringToTime(date_str + " 00:00:10");
     datetime us_time_end_2 =   StringToTime(date_str + " 03:59:50");
     
     PrintFormat("isTradeTime::l_t= %d, b_1= %d, e_1= %d, t_2= %d, e_2= %d", local_time, us_time_begin_1, us_time_end_1, us_time_begin_2, us_time_end_2);
     PrintFormat("isTradeTime::l_t= %s, b_1= %s, e_1= %s, t_2= %s, e_2= %s", 
     TimeToString(local_time, TIME_DATE|TIME_SECONDS), 
     TimeToString(us_time_begin_1, TIME_DATE|TIME_SECONDS), TimeToString(us_time_end_1, TIME_DATE|TIME_SECONDS), 
     TimeToString(us_time_begin_2, TIME_DATE|TIME_SECONDS), TimeToString(us_time_end_2, TIME_DATE|TIME_SECONDS));
     
     if((local_time > us_time_begin_1 && local_time < us_time_end_1) ||
       (local_time > us_time_begin_2 && local_time < us_time_end_2)) {
       return(true);
     } else {
       return(false);
     }
};

