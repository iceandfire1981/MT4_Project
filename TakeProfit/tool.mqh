//+------------------------------------------------------------------+
//|                                                         tool.mqh |
//|                                        Copyright 2018, FRT Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, FRT Corp."
#property link      "https://www.mql5.com"
#property strict

class CTool 
{
 private:
   string   mMainSymbol;
   string   mSlaveSymbol;
   datetime mOldDatetime;
   int      mPriceCount;
   ENUM_TIMEFRAMES mTimeFrames;
   
   double mMainBids[];
   double mSlaveBids[];
   
   double mMainAsks[];
   double mSlaveAsks[];
 
 public:
   CTool(string main_symbol, string slave_symbol, int price_count){
      mMainSymbol = main_symbol;
      mSlaveSymbol = slave_symbol;
      mPriceCount = price_count;
      mOldDatetime = -1; 
      mTimeFrames = PERIOD_M1;
      
      ArrayResize(mMainBids, mPriceCount, 0);
      ArrayInitialize(mMainBids, -1.00);
      
      ArrayResize(mSlaveBids, mPriceCount, 0);
      ArrayInitialize(mSlaveBids, -1.00);
      
      ArrayResize(mMainAsks, mPriceCount, 0);
      ArrayInitialize(mMainAsks, -1.00);
      
      ArrayResize(mSlaveAsks, mPriceCount, 0);
      ArrayInitialize(mSlaveAsks, -1.00);
   };
   
   bool isNewBar(){
      datetime new_datetime = datetime(SeriesInfoInteger(mMainSymbol, mTimeFrames, SERIES_LASTBAR_DATE));
      if ( new_datetime != mOldDatetime && new_datetime ){
         mOldDatetime = new_datetime;
         return(true);
      } else{
         return(false);
      }
   };
   
   void updateData(double m_bid, double m_ask, double s_bid, double s_ask) {
       for(int loop_index = 0; loop_index < mPriceCount - 1; loop_index ++) {
          mMainBids[mPriceCount - 1 - loop_index] = mMainBids[mPriceCount - 1 - loop_index - 1];
       }
       mMainBids[0] = m_bid;
       showFillInfo(mMainBids);
       
       
       for(int loop_index = 0; loop_index < mPriceCount - 1; loop_index ++) {
          mMainAsks[mPriceCount - 1 - loop_index] = mMainAsks[mPriceCount - 1 - loop_index - 1];
       }
       mMainAsks[0] = m_ask;
       showFillInfo(mMainAsks);
       
       for(int loop_index = 0; loop_index < mPriceCount - 1; loop_index ++) {
          mSlaveBids[mPriceCount - 1 - loop_index] = mSlaveBids[mPriceCount - 1 - loop_index - 1];
       }
       mSlaveBids[0] = s_bid;
       showFillInfo(mSlaveBids);
       
       for(int loop_index = 0; loop_index < mPriceCount - 1; loop_index ++) {
          mSlaveAsks[mPriceCount - 1 - loop_index] = mSlaveAsks[mPriceCount - 1 - loop_index - 1];
       }
       mSlaveAsks[0] = s_ask;
       showFillInfo(mSlaveAsks);
       
       PrintFormat("updateData::m_b0= %.5f, m_a0= %.5f, s_b0= %.5f, s_a0= %.5f", mMainBids[0], mMainAsks[0], mSlaveBids[0], mSlaveAsks[0]);
       PrintFormat("updateData::m_bl= %.5f, m_al= %.5f, s_bl= %.5f, s_al= %.5f", 
                    mMainBids[mPriceCount - 1], mMainAsks[mPriceCount - 1], mSlaveBids[mPriceCount - 1], mSlaveAsks[mPriceCount - 1]);
   };
   
   bool isAllFill(){
       bool is_fiiled = true;
       for(int loop_index = 0; loop_index < mPriceCount; loop_index ++) {
          if(mMainBids[loop_index] == -1.00) {
              is_fiiled = false;
              break;
          }
       }
       return(is_fiiled);
   };
   
   void showFillInfo(double &dst_array[]){
     int count = ArraySize(dst_array);
     int filled_count = 0;
     int unfilled_count = 0;
     for(int loop_index = 0; loop_index < count; loop_index ++) {
          if(mMainBids[loop_index] < 0){
               unfilled_count = unfilled_count + 1;
          } else {
               filled_count = filled_count + 1;
          }
     }
     PrintFormat("showFillInfo::filled= %d, unfilled= %d, all= %d", filled_count, unfilled_count, count);
   }
   
   double getMainBidDiff(){
       double diff = mMainBids[mPriceCount - 1] - mMainBids[0];
       return(diff);
   };
   
   double getMainAskDiff(){
       double diff = mMainAsks[mPriceCount - 1] - mMainAsks[0];
       return(diff);
   };
   
   double getSlaveBidDiff(){
       double diff = mSlaveBids[mPriceCount - 1] - mSlaveBids[0];
       return(diff);
   };
   
   double getSlaveAskDiff(){
       double diff = mSlaveAsks[mPriceCount - 1] - mSlaveAsks[0];
       return(diff);
   };
   
   void changeTimeFrame(ENUM_TIMEFRAMES input_timeframe) {
      mTimeFrames = input_timeframe;
      mOldDatetime = -1;
   };
};