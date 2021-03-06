//+------------------------------------------------------------------+
//|                                                TakeProfit_UE.mq4 |
//|                                        Copyright 2018, FRT Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FRT Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include "tool.mqh"

//--- input parameters
input int      input_hold_time=60;      //持仓时间（单位：秒）
input int      input_point_diff=5;      //波动值
input int      input_take_profit=60;    //止盈设置（单位：点）
input int      input_stop_loss=60;      //止损设置（单位：点）
input double   input_slip=0;            //滑点
input int      input_ticket_num = 2;    //收集Ticket数量（单位：个）    
input string   input_op_sa="USOIL";     //被控资产
input double   input_shares_num=0.1;    //执行数量（单位：手）

CTool* mTool;
double usoil_point;
double ukoil_point;
double usoil_sl;
double usoil_tp;
double ukoil_sl;
double ukoil_tp;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   mTool = new CTool(Symbol(), input_op_sa, input_ticket_num);
   usoil_point = MarketInfo(Symbol(), MODE_POINT);
   ukoil_point = MarketInfo(input_op_sa, MODE_POINT);
   
   double usoil_stop_level = MarketInfo(Symbol(), MODE_STOPLEVEL);
   if(input_stop_loss < usoil_stop_level){
      usoil_sl = usoil_stop_level;    
   } else {
      usoil_sl = input_stop_loss;
   }
   
   if(input_take_profit < usoil_stop_level){
      usoil_tp = usoil_stop_level;    
   } else {
      usoil_tp = input_take_profit;
   }
   
   double ukoil_stop_level = MarketInfo(input_op_sa, MODE_STOPLEVEL);
   if(input_stop_loss < ukoil_stop_level){
      ukoil_sl = ukoil_stop_level;    
   } else {
      ukoil_sl = input_stop_loss;
   }
   
   if(input_take_profit < ukoil_stop_level){
      ukoil_tp = ukoil_stop_level;    
   } else {
      ukoil_tp = input_take_profit;
   }

   PrintFormat("Oninit::us_p= %.3f, uk_p= %.3f, us_sl= %.3f, uk_sl= %.3f, us_sl1= %.3f, us_tp1= %.3f, uk_sl1= %.3f, uk_tp1= %.3f,", 
            usoil_point, ukoil_point, usoil_stop_level, ukoil_stop_level, usoil_sl, usoil_tp, ukoil_sl, ukoil_tp);
   EventSetTimer(1);
            
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
   double s_bid = MarketInfo(input_op_sa, MODE_BID);
   double s_ask = MarketInfo(input_op_sa, MODE_ASK);
               
   mTool.updateData(Bid, Ask, s_bid, s_ask);//装填数据
   bool has_order = hasOrder();
   PrintFormat("OnTick::m_symbol= %s, m_bid= %.5f, m_ask= %.5f, s_bid= %.5f, s_ask= %.5f, has_order= %d", 
               Symbol(), Bid, Ask, s_bid, s_ask, has_order);
   
   if(has_order == false) {
       if(isTradeTime() == true) {
          mTool.updateData(Bid, Ask, s_bid, s_ask);//装填数据
          if(mTool.isAllFill() == true){
               //获取各个品种的价差
              double usoil_diff = mTool.getMainBidDiff();
              double ukoil_diff = mTool.getSlaveBidDiff();
              if (MathAbs((usoil_diff/usoil_point) - (ukoil_diff/ukoil_point)) >= 
                         (input_point_diff + input_take_profit)){
                 double ukoil_price_bid = MarketInfo(input_op_sa, MODE_BID);
                 double ukoil_price_ask = MarketInfo(input_op_sa, MODE_ASK);
                 double ukoil_price_sl_buy = ukoil_price_bid - (MarketInfo(input_op_sa, MODE_POINT) * ukoil_sl);
                 double ukoil_price_tp_buy = ukoil_price_bid + (MarketInfo(input_op_sa, MODE_POINT) * ukoil_tp); 
                 double ukoil_price_sl_sell = ukoil_price_ask + (MarketInfo(input_op_sa, MODE_POINT) * ukoil_sl);
                 double ukoil_price_tp_sell = ukoil_price_ask - (MarketInfo(input_op_sa, MODE_POINT) * ukoil_tp);
                 if (usoil_diff > 0) {
                    OrderSend(input_op_sa, OP_BUY, input_shares_num, ukoil_price_bid, 
                              input_slip, ukoil_price_sl_buy, ukoil_price_tp_buy, "x3"); 
                 } else if (usoil_diff < 0) {
                    OrderSend(input_op_sa, OP_SELL, input_shares_num, ukoil_price_ask, 
                              input_slip, ukoil_price_sl_sell, ukoil_price_tp_sell, "x4");  
                 }
              }           
          }  
       }
   }
};
//+------------------------------------------------------------------+

 bool isTradeTime(){
   datetime ue_time_begin = D'14:30:00';
   datetime ue_time_end   = D'21:29:59';
   
   datetime local_time = TimeLocal();
   
   if (local_time < ue_time_end && local_time > ue_time_begin) {
      return(true);
   } else {
      return(false);
   }
 };
 
 //判断是否有交易记录
bool hasOrder()
{
  int orders_count = OrdersTotal();
  bool is_targeted = false;
  PrintFormat("hasOrder::order_count= %d", orders_count);
  for(int order_index = 0; order_index < orders_count; order_index++)
  {
    if (OrderSelect(order_index, SELECT_BY_POS, MODE_TRADES) == true){
      string order_comment = StringSubstr(OrderComment(), 0, 1);
      PrintFormat("hasOrder::orderx= %d, comm= %s, comm1= %s", order_index, OrderComment(), order_comment);
      if (StringCompare(order_comment, "x") == 0){
        is_targeted = true;
        break;
      }
    } else {
      PrintFormat("Order select %d false=====", order_index);
    }
  };
  return(is_targeted);
};

