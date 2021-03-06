//+------------------------------------------------------------------+
//|                                                TakeProfit_US.mq4 |
//|                                        Copyright 2018, FRT Corp. |
//|                                             https://www.mql5.com |
//|修改点：                                                          |
//|1、去掉止损和止盈                                                 |
//|2、修改一些BUG                                                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FRT Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "tool.mqh"

//--- input parameters
input int      input_hold_time     = 60;     //持仓时间（单位：秒）
input int      input_point_diff    = 50;     //波动值  （单位：点） 
input int      input_take_profit   = 60;     //止盈设置（单位：点）
input int      input_stop_loss     = 60;     //止损设置（单位：点）
input int      input_float_tp      = 10;     //浮动止盈（单位：点）
input int      input_ticket_num    = 7;      //收集Ticket数量（单位：个）
input int      input_timer_setting = 5;      //定时器设置（单位：秒）
input double   input_slip          = 0;      //滑点
input double   input_shares_num    = 0.1;    //执行数量（单位：手）
input string   input_op_sa         = "UKOIL";//被控资产
input string   input_order_prefix  = "a";    //订单前缀

CTool* mTool;
double usoil_point;
double ukoil_point;
double usoil_tp_f;
double ukoil_tp_f;
double target_point;

string order_common_1;
string order_common_2;
string order_common_3;
string order_common_4;
string record_file_name;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(){
   mTool = new CTool(Symbol(), input_op_sa, input_ticket_num);
   order_common_1 = input_order_prefix + IntegerToString(input_ticket_num) + "_1";
   order_common_2 = input_order_prefix + IntegerToString(input_ticket_num) + "_2";
   order_common_3 = input_order_prefix + IntegerToString(input_ticket_num) + "_3";
   order_common_4 = input_order_prefix + IntegerToString(input_ticket_num) + "_4";
   
   record_file_name = input_order_prefix + "_" + IntegerToString(input_ticket_num) + "_order_file.txt";
   
   //获取主/副资产点数单位（单位：美元）
   usoil_point = MarketInfo(Symbol(), MODE_POINT);
   ukoil_point = MarketInfo(input_op_sa, MODE_POINT);
   
   //计算主/副资产的浮动止盈点价格
   usoil_tp_f = usoil_point * input_float_tp;
   ukoil_tp_f = ukoil_point * input_float_tp; 
   target_point = input_point_diff + input_take_profit;

   PrintFormat("Oninit::usoil_point= %.5f, ukoil_point= %.5f, usoil_tp_f= %.5f, ukoil_tp_f= %.5f, target_point= %.5f, record_file= %s", 
            usoil_point, ukoil_point, usoil_tp_f, ukoil_tp_f, target_point, record_file_name);
   EventSetTimer(input_timer_setting);
            
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  EventKillTimer();        
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(){

   double s_bid = MarketInfo(input_op_sa, MODE_BID);
   double s_ask = MarketInfo(input_op_sa, MODE_ASK);
   mTool.updateData(Bid, Ask, s_bid, s_ask);//装填数据
               
   bool has_order = hasOrder();
   bool is_trade_time = isTradeTime();
   bool is_all_filled = mTool.isAllFill();
   PrintFormat("OnTick::m_symbol= %s, m_bid= %.5f, m_ask= %.5f, s_bid= %.5f, s_ask= %.5f, has_order= %d, i_t_t= %d, i_a_f= %d", 
               Symbol(), Bid, Ask, s_bid, s_ask, has_order, is_trade_time, is_all_filled);
   
   if(has_order == false) {
       if(is_trade_time == true) {
          if(is_all_filled == true){
               //获取各个品种的价差
              double usoil_diff = mTool.getMainBidDiff() / usoil_point;
              double ukoil_diff = mTool.getSlaveBidDiff()/ ukoil_point;
              PrintFormat("OnTrade::usoil_diff= %.5f, ukoil_diff= %.5f, target_point= %.5f", 
                         usoil_diff, ukoil_diff, target_point);
              
              if (MathAbs(usoil_diff - ukoil_diff) >= target_point){
                 if (usoil_diff > 0) {
                    
                    if(OrderSend(input_op_sa, OP_BUY, input_shares_num, s_bid, input_slip, 0, 0, order_common_1) < 0 ){
                         PrintFormat("OnTrade::BUY No.1 false, error= %d", GetLastError());   
                    } else {
                         PrintFormat("OnTrade::BUY No.1 success, Write file for No.1"); 
                         int order_file_handle = FileOpen(record_file_name, FILE_READ|FILE_WRITE|FILE_TXT);
                         if(order_file_handle != INVALID_HANDLE){
                              string order_record = input_op_sa + "|BUY|" + DoubleToStr(s_bid, 5) + "|" + 
                                        DoubleToStr(usoil_diff, 5) + "|" + order_common_1 + "|" 
                                        + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
                              FileSeek(order_file_handle, 0, SEEK_END);
                              FileWriteString(order_file_handle, order_record);
                         }
                         FileClose(order_file_handle);
                    }
                 } else if (usoil_diff < 0) {
                    
                    if(OrderSend(input_op_sa, OP_SELL, input_shares_num, s_bid, input_slip, 0, 0, order_common_2) < 0){
                      PrintFormat("OnTrade::SELL No.2 false, error= %d", GetLastError());
                    } else {
                         PrintFormat("OnTrade::BUY No.2 success, Write file for No.2"); 
                         int order_file_handle_1 = FileOpen(record_file_name, FILE_READ|FILE_WRITE|FILE_TXT);
                         if(order_file_handle_1 != INVALID_HANDLE){
                              string order_record = input_op_sa + "|SELL|" + DoubleToStr(s_ask, 5) + "|" + 
                                        DoubleToStr(usoil_diff, 5) + "|" + order_common_2 + "|" 
                                        + TimeToStr(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
                              FileSeek(order_file_handle_1, 0, SEEK_END);
                              FileWriteString(order_file_handle_1, order_record);
                         }
                         FileClose(order_file_handle_1);
                    }
                 }
              }           
          }  
       }
   }
};

void OnTimer() {
  bool has_order = hasOrder();
  if(has_order == true) {
     handleOrder();
  }
}

//判断是否有交易记录
bool hasOrder(){
  int orders_count = OrdersTotal();
  bool is_targeted = false;
  
  for(int order_index = 0; order_index < orders_count; order_index++)
  {
    if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true){
          string order_comment = OrderComment();
          if (StringCompare(order_comment, order_common_1) == 0 || StringCompare(order_comment, order_common_2) == 0 ||
               StringCompare(order_comment, order_common_3) == 0 || StringCompare(order_comment, order_common_4) == 0){
               is_targeted = true;
               break;
          }
    } else {
          PrintFormat("Order select %d false=====", order_index);
    }
  };
  return(is_targeted);
};

void handleOrder(){
   int orders_count = OrdersTotal();
   double usoil_ask = Ask;
   double usoil_bid = Bid;
   double ukoil_ask = MarketInfo(input_op_sa, MODE_ASK);
   double ukoil_bid = MarketInfo(input_op_sa, MODE_BID);
   double usoil_tp_price = input_take_profit * usoil_point;
   double ukoil_tp_price = input_take_profit * ukoil_point;
   double usoil_sl_price = input_stop_loss * usoil_point;
   double ukoil_sl_price = input_stop_loss * ukoil_point;
   
   PrintFormat("handleTakeProfit::orders_count= %d, us_ask= %.5f, us_bid= %.5f, uk_ask= %.5f, uk_bid= %.5f, us_tp= %.5f, uk_tp= .5f", 
            orders_count, usoil_ask, usoil_bid, ukoil_ask, ukoil_bid, usoil_tp_price, ukoil_tp_price);
   
   for(int order_index = 0; order_index < orders_count; order_index ++) {
      if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true) {
         
         string order_comment = OrderComment();
         double order_price = OrderOpenPrice();
         int    order_ticket = OrderTicket();
         double order_lots   = OrderLots();
         datetime order_open_time = OrderOpenTime();
         
         PrintFormat("handleTakeProfit:info::comment= %s, price= %.5f, ticket= %d, lots= %.3f, open_time= %s", 
                  order_comment, order_price, order_ticket, order_lots, 
                  TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS));
         
         if(StringCompare(order_comment, order_common_1) == 0) {
           if ((TimeCurrent() - order_open_time) >= input_hold_time && isTradeTime() == true){
                PrintFormat("handleTakeProfit::tp close::x1::overtime");
                OrderClose(order_ticket, order_lots, ukoil_ask, input_slip, clrSaddleBrown);
           } else {
                if (ukoil_ask >= (ukoil_tp_price + order_price - ukoil_tp_f)){
                  PrintFormat("handleTakeProfit::tp close::x1");
                  OrderClose(order_ticket, order_lots, ukoil_ask, input_slip, clrSaddleBrown);
                } else if (ukoil_ask <= (order_price - ukoil_sl_price)) {
                  PrintFormat("handleTakeProfit::sl close::x1");
                  OrderClose(order_ticket, order_lots, ukoil_ask, input_slip, clrSaddleBrown);
                }    
           }
         } else if (StringCompare(order_comment, order_common_2) == 0) {
           if ((TimeCurrent() - order_open_time) >= input_hold_time && isTradeTime() == true){
                PrintFormat("handleTakeProfit::tp close::x2::overtime");
                OrderClose(order_ticket, order_lots, ukoil_bid, input_slip, clrSaddleBrown);        
           } else {
                if (ukoil_bid <= (order_price - ukoil_tp_price + ukoil_tp_f)){
                  PrintFormat("handleTakeProfit::tp close::x2");
                  OrderClose(order_ticket, order_lots, ukoil_bid, input_slip, clrSaddleBrown);
                } else if (ukoil_bid > (order_price + ukoil_sl_price)){
                  PrintFormat("handleTakeProfit::sl close::x2");
                  OrderClose(order_ticket, order_lots, ukoil_bid, input_slip, clrSaddleBrown);
                }    
           }
         } else if (StringCompare(order_comment, order_common_3) == 0) {
           if ((TimeCurrent() - order_open_time) >= input_hold_time && isTradeTime() == true){
                PrintFormat("handleTakeProfit::tp close::x3::overtime");
                OrderClose(order_ticket, order_lots, usoil_ask, input_slip, clrSaddleBrown);
           } else {
                if (usoil_ask >= (usoil_tp_price + order_price - usoil_tp_f)){
                  PrintFormat("handleTakeProfit::tp close::x3");
                  OrderClose(order_ticket, order_lots, usoil_ask, input_slip, clrSaddleBrown);
                } else if (usoil_ask <= (order_price - usoil_sl_price)){
                  PrintFormat("handleTakeProfit::sl close::x3");
                  OrderClose(order_ticket, order_lots, usoil_ask, input_slip, clrSaddleBrown);  
                }    
           }
         } else if (StringCompare(order_comment, order_common_4) == 0 ) {
           if ((TimeCurrent() - order_open_time) >= input_hold_time && isTradeTime() == true){
                PrintFormat("handleTakeProfit::tp close::x4::overtime");
                OrderClose(order_ticket, order_lots, usoil_bid, input_slip, clrSaddleBrown);
           } else {
                if (usoil_bid <= (order_price - usoil_tp_price - usoil_tp_f)){
                  PrintFormat("handleTakeProfit::tp close::x4");
                  OrderClose(order_ticket, order_lots, usoil_bid, input_slip, clrSaddleBrown);
                } else if (usoil_bid > (order_price + usoil_sl_price)){
                  PrintFormat("handleTakeProfit::sl close::x4");
                  OrderClose(order_ticket, order_lots, usoil_bid, input_slip, clrSaddleBrown);
                }    
           }
         }
      } else {
         PrintFormat("handleTakeProfit::get order info %d false, skip it==============", order_index);
      }  
   }
}

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
