//+------------------------------------------------------------------+
//|                                                PivotStopHunt.mq5  |
//|                             Corrected by OpenAI's ChatGPT         |
//+------------------------------------------------------------------+
#property copyright "OpenAI"
#property link      "https://openai.com"
#property version   "1.12"
#property description "Indicator showing pivots and stop hunts."
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   6

//--- plots
#property indicator_label1  "ResistancePivot"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_width1  1
#property indicator_style1  STYLE_SOLID

#property indicator_label2  "SupportPivot"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrBlue
#property indicator_width2  1
#property indicator_style2  STYLE_SOLID

#property indicator_label3  "StopHuntResistance"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrMagenta
#property indicator_width3  2
#property indicator_style3  STYLE_SOLID

#property indicator_label4  "StopHuntSupport"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrCyan
#property indicator_width4  2
#property indicator_style4  STYLE_SOLID

#property indicator_label5 "UpwardPullback"
#property indicator_type5 DRAW_ARROW
#property indicator_color5 clrBlue
#property indicator_width5 1
#property indicator_style5 STYLE_SOLID

#property indicator_label6 "DownwardPullback"
#property indicator_type6 DRAW_ARROW
#property indicator_color6 clrRed
#property indicator_width6 1
#property indicator_style6 STYLE_SOLID

//--- input parameters
input int PivotLookBack = 5; // Number of candles to the left and right
input int MaxPivotAge   = 10; // Maximum age of pivots in days

//--- indicator buffers
double ResistancePivotBuffer[];
double SupportPivotBuffer[];
double StopHuntResistanceBuffer[];
double StopHuntSupportBuffer[];
double UpwardPullbackBuffer[];
double DownwardPullbackBuffer[];

//--- Global Variables for upward
bool upwardTrend = false;
int lastUpgoingValidIndex = -1;
int upwardStartIndex = -1;
double lastSupport = 0.0;
bool findPullback=false;

//--- Global Variables for downward
bool downwardTrend = false;
int lastDowngoingValidIndex = -1;
int downwardStartIndex = -1;
double lastResistance = 0.0;
bool findDownwardPullback=false;


//--- Global variables
struct PivotPoint
{
    int    index;
    double price;
    bool   touched;
};

PivotPoint resistancePivots[];
PivotPoint supportPivots[];

PivotPoint likelyUpwardPullback;
PivotPoint validUpwardPullbacks[];

PivotPoint likelyDownwardPullback;
PivotPoint validDownwardPullbacks[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- indicator buffers mapping
    SetIndexBuffer(0, ResistancePivotBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SupportPivotBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, StopHuntResistanceBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, StopHuntSupportBuffer, INDICATOR_DATA);
    SetIndexBuffer(4, UpwardPullbackBuffer,INDICATOR_DATA);
    SetIndexBuffer(5, DownwardPullbackBuffer,INDICATOR_DATA);

    //--- set arrow codes
    PlotIndexSetInteger(0, PLOT_ARROW, 217); // up arrow for resistance pivot
    PlotIndexSetInteger(1, PLOT_ARROW, 218); // down arrow for support pivot
    PlotIndexSetInteger(2, PLOT_ARROW, 241); // Stop hunt resistance
    PlotIndexSetInteger(3, PLOT_ARROW, 242); // Stop hunt support
    PlotIndexSetInteger(4, PLOT_ARROW, 218); // downward for upward pullabck
    PlotIndexSetInteger(5, PLOT_ARROW, 217); // up for downward pullabck

    //--- set empty values to EMPTY_VALUE
    ArrayInitialize(ResistancePivotBuffer, EMPTY_VALUE);
    ArrayInitialize(SupportPivotBuffer, EMPTY_VALUE);
    ArrayInitialize(StopHuntResistanceBuffer, EMPTY_VALUE);
    ArrayInitialize(StopHuntSupportBuffer, EMPTY_VALUE);
    ArrayInitialize(UpwardPullbackBuffer,EMPTY_VALUE);
    ArrayInitialize(DownwardPullbackBuffer,EMPTY_VALUE);

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
    if(rates_total <= PivotLookBack * 2)
        return(0); // Not enough data

    // *** Pivot Identification Loop ***
    // Determine the starting point for pivot identification
    int start_pivot = (prev_calculated > PivotLookBack) ? (prev_calculated - PivotLookBack) : PivotLookBack;
    int end_pivot = rates_total - PivotLookBack;

    for(int i = start_pivot; i < end_pivot; i++)
    {
        datetime pivotTime = time[i];

        // Check if the pivot is older than MaxPivotAge
        if(time[rates_total - 1] - pivotTime > MaxPivotAge * 86400)
            continue;

        bool isResistance = true;
        bool isSupport = true;

        //--- Identify if the current candle is a pivot
        for(int j = 1; j <= PivotLookBack; j++)
        {
            if(high[i] <= high[i - j] || high[i] <= high[i + j])
                isResistance = false;
            if(low[i] >= low[i - j] || low[i] >= low[i + j])
                isSupport = false;

            // Early exit if not a pivot
            if(!isResistance && !isSupport)
                break;
        }

        //--- If it's a Resistance Pivot
        if(isResistance)
        {
            //PlaySound("alert.wav");
            // Debugging message
            Print("This is a Resistance Pivot at ", TimeToString(time[i], TIME_DATE|TIME_MINUTES), " with value ", high[i]);
            
            // Assign to buffer for plotting
            ResistancePivotBuffer[i] = high[i];
            
            // Add to resistance pivots array
            AddPivot(resistancePivots, i, high[i]);
        }
        else
        {
            ResistancePivotBuffer[i] = EMPTY_VALUE;
        }

        //--- If it's a Support Pivot
        if(isSupport)
        {
            //PlaySound("alert.wav");
            // Debugging message
            Print("This is a Support Pivot at ", TimeToString(time[i], TIME_DATE|TIME_MINUTES), " with value ", low[i]);
            
            // Assign to buffer for plotting
            SupportPivotBuffer[i] = low[i];
            
            // Add to support pivots array
            AddPivot(supportPivots, i, low[i]);
        }
        else
        {
            SupportPivotBuffer[i] = EMPTY_VALUE;
        }
    }
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////    

   // *** Upward Pullback identification Loop *** 
   int start=(prev_calculated>0)? prev_calculated -1 : 2 ;
   int end = rates_total;
   
   for(int i=start; i < end ; i++)
   {
      // check if this is too old , do not process to find pullback
      datetime candleTime = time[i];
      if(time[rates_total - 1] - candleTime > MaxPivotAge * 86400)
         continue;
         
      // if an upgoind trend has been started before 
      if(upwardTrend)
      {  
  
        // Print("in upwardTrend at:",candleTime);
         if(low[i]<low[lastUpgoingValidIndex]) // if a candle breaks down the low of last upgoing candle the we go in phase of finding pulback
         {
           // Print("in upwardTrend and low[i]<low[lastUpgoingValidIndex] at:",candleTime);
            if(high[i]>= high[lastUpgoingValidIndex])
            {  
              // Print("in upwardTrend and low[i]<low[lastUpgoingValidIndex] and high[i]>= high[lastUpgoingValidIndex] at:",candleTime);
               lastUpgoingValidIndex=i;
            }   
               
            // cancle upward trend
            upwardTrend=false;
            upwardStartIndex=-1;
            
            // store likely upward pullback
            likelyUpwardPullback.index=i;
            likelyUpwardPullback.price=low[i];
            likelyUpwardPullback.touched=false;
            
            findPullback=true; // start finding pull back
         }
         // update last upgoing candle index
         else if(high[i]>= high[lastUpgoingValidIndex])
         {
          //  Print("in upwardTrend and high[i]>= high[lastUpgoingValidIndex] at:",candleTime);
            
            lastUpgoingValidIndex=i;
         }
         
      }
      // if we are in finding pullback Phase
      else if(findPullback)
      {
       //  Print("in findPullback at:",candleTime);
         // first scenario, part 1, if we broke the last support, so the upward trend is broken and finding pullback is cancled
         if(low[i]<lastSupport)
         {
           // Print("in findPullback and low[i]<lastSupport at:",candleTime);
            if(high[i] >= high[lastUpgoingValidIndex])
            {
              // Print("in findPullback and low[i]<lastSupport and high[i] >= high[lastUpgoingValidIndex] at:",candleTime);
               if(close[i]> open[i])
               {
                 // Print("in findPullback and low[i]<lastSupport and high[i] >= high[lastUpgoingValidIndex] and i-- at:",candleTime);
                  i--;   
               }  
            }
            
            findPullback=false;
            lastUpgoingValidIndex=-1; // we no longer seek for a candle to break the high of last upgoing valid candle
               

         }
         // first scenario, part2, if we are seeing downward candles, we should keep updating pullback
         else if(low[i]<likelyUpwardPullback.price)
         {
           // Print("in findPullback and low[i]<likelyUpwardPullback.price at:",candleTime);
            likelyUpwardPullback.index=i;
            likelyUpwardPullback.price=low[i];
            
            if(high[i] >= high[lastUpgoingValidIndex])
            {
              // Print("in findPullback and low[i]<likelyUpwardPullback.price and high[i] >= high[lastUpgoingValidIndex] at:",candleTime);
               lastUpgoingValidIndex=i;
            }
            
         }
         // second way, if high be higher than high of last upgoing valid candle, then we have a valid upward pullback
         else if(high[i]> high[lastUpgoingValidIndex])
         {
          //   Print("in findPullback and high[i]> high[lastUpgoingValidIndex] at:",candleTime);
             
             if(close[i] > open[i]) // first check if it is an upgoing candle
             {
                Print("Upward Pullback has been founded at :",time[likelyUpwardPullback.index]," with pullback price:",likelyUpwardPullback.price);
                Print("lastUpgoingValidCandle at :",time[lastUpgoingValidIndex]," with price:",high[lastUpgoingValidIndex]);
                Print("Fixed at :",time[i]," with Price:",high[i]);
                PlaySound("alert.wav");
               // Print("in findPullback and high[i]> high[lastUpgoingValidIndex] and close[i] > open[i] at:",candleTime);
                lastUpgoingValidIndex=-1; // we again need to seek for a upward trend
                findPullback=false;
                // Add to array
                int size=ArraySize(validUpwardPullbacks);
                int newSize=size+1;
                ArrayResize(validUpwardPullbacks,newSize);
                validUpwardPullbacks[size] = likelyUpwardPullback;
                
                //plot pullback
                UpwardPullbackBuffer[likelyUpwardPullback.index]=likelyUpwardPullback.price;
               // Print(likelyUpwardPullback.index);

                i--;        
             }
             lastUpgoingValidIndex=i;

         }
         
      }
      // Check for at least two consecutive upgoing candles, because we are not in upward trend nor in finding pullback phase
      else if(high[i-1] >= high[i-2] && high[i] >= high[i-1])
      {
        // Print("in high[i-1] >= high[i-2] && high[i] >= high[i-1] at:",candleTime );
         if(close[i] > open[i] && close[i-1] > open[i-1]) // check if both candles are upgoing candles
         {  
           // Print("in high[i-1] >= high[i-2] && high[i] >= high[i-1] and close[i] > open[i] && close[i-1] > open[i-1] at:",candleTime );
            upwardTrend = true;  // set the trend to be upgoing
            lastUpgoingValidIndex = i; // store last upgoing valid candle index
            
            upwardStartIndex = i-1;    // store a candle before upward start candle
            
            // Calculate last support
            double low2 = low[upwardStartIndex];
            double low1 = low[upwardStartIndex -1];
            double low0 = low[upwardStartIndex -2];
            lastSupport = MathMin(MathMin(low2, low1), low0);
         }

      }

   }
   
   // *** Downward Pullback identification Loop *** 
   for(int j=start; j < end ; j++)
   {
      // check if this is too old , do not process to find pullback
      datetime candleTime = time[j];
      if(time[rates_total - 1] - candleTime > MaxPivotAge * 86400)
         continue;
         
      // if a downgoind trend has been started before 
      if(downwardTrend)
      {  
  
        // Print("in upwardTrend at:",candleTime);
         if(high[j]>high[lastDowngoingValidIndex]) // if a candle breaks up the high of last downgoing candle the we go in phase of finding downward pulback
         {
           // Print("in upwardTrend and low[i]<low[lastUpgoingValidIndex] at:",candleTime);
            if(low[j]<= low[lastDowngoingValidIndex])
            {  
              // Print("in upwardTrend and low[i]<low[lastUpgoingValidIndex] and high[i]>= high[lastUpgoingValidIndex] at:",candleTime);
               lastDowngoingValidIndex=j;
            }   
               
            // cancle downward trend
            downwardTrend=false;
            downwardStartIndex=-1;
            
            // store likely downward pullback
            likelyDownwardPullback.index=j;
            likelyDownwardPullback.price=high[j];
            likelyDownwardPullback.touched=false;
            
            findDownwardPullback=true; // start finding downward pull back
         }
         // update last downgoing candle index
         else if(low[j]<= low[lastDowngoingValidIndex])
         {
          //  Print("in upwardTrend and high[i]>= high[lastUpgoingValidIndex] at:",candleTime);
            
            lastDowngoingValidIndex=j;
         }
         
      }
      // if we are in finding downward pullback Phase
      else if(findDownwardPullback)
      {
       //  Print("in findPullback at:",candleTime);
         // first scenario, part 1, if we broke the last resistance, so the downward trend is broken and finding downward pullback is cancled
         if(high[j]>lastResistance)
         {
           // Print("in findPullback and low[i]<lastSupport at:",candleTime);
            if(low[j] <= low[lastDowngoingValidIndex])
            {
              // Print("in findPullback and low[i]<lastSupport and high[i] >= high[lastUpgoingValidIndex] at:",candleTime);
               if(close[j]< open[j])
               {
                 // Print("in findPullback and low[i]<lastSupport and high[i] >= high[lastUpgoingValidIndex] and i-- at:",candleTime);
                  j--;   
               }  
            }
            
            findDownwardPullback=false;
            lastDowngoingValidIndex=-1; // we no longer seek for a candle to break the low of last downgoing valid candle
               

         }
         // first scenario, part2, if we are seeing upward candles, we should keep updating downward pullback
         else if(high[j]>likelyDownwardPullback.price)
         {
           // Print("in findPullback and low[i]<likelyUpwardPullback.price at:",candleTime);
            likelyDownwardPullback.index=j;
            likelyDownwardPullback.price=high[j];
            
            if(low[j] <= low[lastDowngoingValidIndex])
            {
              // Print("in findPullback and low[i]<likelyUpwardPullback.price and high[i] >= high[lastUpgoingValidIndex] at:",candleTime);
               lastDowngoingValidIndex=j;
            }
            
         }
         // second way, if low be lower than low of last downgoing valid candle, then we have a valid downward pullback
         else if(low[j]< low[lastDowngoingValidIndex])
         {
          //   Print("in findPullback and high[i]> high[lastUpgoingValidIndex] at:",candleTime);
             
             if(close[j] < open[j]) // first check if it is an downgoing candle
             {
                Print("Downward Pullback has been founded at :",time[likelyDownwardPullback.index]," with pullback price:",likelyDownwardPullback.price);
                Print("lastDowngoingValidCandle at :",time[lastDowngoingValidIndex]," with price:",low[lastDowngoingValidIndex]);
                Print("Fixed at :",time[j]," with Price:",low[j]);
                PlaySound("alert.wav");
               // Print("in findPullback and high[i]> high[lastUpgoingValidIndex] and close[i] > open[i] at:",candleTime);
                lastDowngoingValidIndex=-1; // we again need to seek for a downward trend
                findDownwardPullback=false;
                // Add to array
                int sizee=ArraySize(validDownwardPullbacks);
                int newSizee=sizee+1;
                ArrayResize(validDownwardPullbacks,newSizee);
                validDownwardPullbacks[sizee] = likelyDownwardPullback;
                
                //plot pullback
                DownwardPullbackBuffer[likelyDownwardPullback.index]=likelyDownwardPullback.price;
               // Print(likelyUpwardPullback.index);

                j--;        
             }
             lastDowngoingValidIndex=j;

         }
         
      }
      // Check for at least two consecutive downgoing candles, because we are not in downward trend nor in finding downward pullback phase
      else if(low[j-1] <= low[j-2] && low[j] <= low[j-1])
      {
        // Print("in high[i-1] >= high[i-2] && high[i] >= high[i-1] at:",candleTime );
         if(close[j] < open[j] && close[j-1] < open[j-1]) // check if both candles are downgoing candles
         {  
           // Print("in high[i-1] >= high[i-2] && high[i] >= high[i-1] and close[i] > open[i] && close[i-1] > open[i-1] at:",candleTime );
            downwardTrend = true;  // set the trend to be downgoing
            lastDowngoingValidIndex = j; // store last downgoing valid candle index
            
            downwardStartIndex = j-1;    // store a candle before downward start candle
            
            // Calculate last resistance
            double high2 = high[downwardStartIndex];
            double high1 = high[downwardStartIndex -1];
            double high0 = high[downwardStartIndex -2];
            lastResistance = MathMax(MathMax(high2, high1), high0);
         }

      }

   }


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // *** Stop Hunt Detection Loop ***
    // Determine the starting point for stop hunt detection
    int start_sh = (prev_calculated > 0) ? (prev_calculated - 1) : 0;
    int end_sh = rates_total - 1; // Process up to the latest candle

    for(int i = start_sh; i < end_sh; i++)
    {
        // Check for Resistance Stop Hunts
        CheckAndHandlePivots(resistancePivots, high, low, close, i, StopHuntResistanceBuffer, true, rates_total, time);

        // Check for Support Stop Hunts
        CheckAndHandlePivots(supportPivots, low, high, close, i, StopHuntSupportBuffer, false, rates_total, time);
        
        // Check for Resistance Stop Hunts based on downward pullback
        CheckAndHandlePivots(validDownwardPullbacks, high, low, close, i, StopHuntResistanceBuffer, true, rates_total, time);
        
        // Check for Support Stop Hunts based on upward pullback
        CheckAndHandlePivots(validUpwardPullbacks, low, high, close, i, StopHuntSupportBuffer, false, rates_total, time);
    }

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Function to add a pivot point to the array                       |
//+------------------------------------------------------------------+
void AddPivot(PivotPoint &pivots[], int index, double price)
{
    // Check if the pivot already exists
    int size = ArraySize(pivots);
    for(int i = 0; i < size; i++)
    {
        if(pivots[i].index == index)
            return; // Pivot already exists
    }

    ArrayResize(pivots, size + 1);
    pivots[size].index   = index;
    pivots[size].price   = price;
    pivots[size].touched = false;
}


//+------------------------------------------------------------------+
//| Function to check and handle pivot touches and stop hunts        |
//+------------------------------------------------------------------+
void CheckAndHandlePivots(PivotPoint &pivots[], const double &priceArray[], const double &oppositePriceArray[], const double &close[], int currentIndex, double &buffer[], bool isResistance, int rates_total,const datetime &time[])
{
    int pivotCount = ArraySize(pivots);
    for(int j = 0; j < pivotCount; j++)
    {
        // Skip if pivot is already hunted or touched more than one time
        if(pivots[j].touched)
            continue;

        int pivotIndex = pivots[j].index;
        double pivotPrice = pivots[j].price;

        // Ensure we don't process pivots from the future
        if(pivotIndex >= currentIndex)
            continue;

        // Check if the current candle touches the pivot
        bool touched = false;
        if(isResistance)
        {
            // For resistance pivots, touch occurs if high >= pivotPrice
            if(priceArray[currentIndex] >= pivotPrice)
            {
                //Print("A candle touched Resistance Pivot at ", currentIndex, " with value ", priceArray[currentIndex]);
                touched = true;
            }
        }
        else
        {
            // For support pivots, touch occurs if low <= pivotPrice
            if(priceArray[currentIndex] <= pivotPrice)
                touched = true;
        }

        if(touched)
        {
            pivots[j].touched = true;

            //--- Check for Stop Hunt
            // Resistance Stop Hunt: High > pivot and Close < pivot with Close < previous Close
            // Support Stop Hunt: Low < pivot and Close > pivot with Close > previous Close
            bool stopHunt = false;
            bool altStopHunt=false;
            if(isResistance)
            {
                if(priceArray[currentIndex] > pivotPrice && close[currentIndex] < pivotPrice)
                {
                    if(currentIndex > 0 && close[currentIndex] < close[currentIndex - 1])
                    {
                        stopHunt = true;
                    }
                }// if first candle could not satisfy stop hunt condtion for the pivot, we check whether the next candle satisfy stop hunt condition for the currenct candle(which is the first candle that could touch the pivot))
                else if(priceArray[currentIndex+1] > priceArray[currentIndex] && close[currentIndex+1] < priceArray[currentIndex])
                {
                    if(currentIndex > 0 && close[currentIndex+1] < close[currentIndex])
                    {
                        altStopHunt = true;
                    }
                }
            }
            else
            {
                if(priceArray[currentIndex] < pivotPrice && close[currentIndex] > pivotPrice)
                {
                    if(currentIndex > 0 && close[currentIndex] > close[currentIndex - 1])
                    {
                        stopHunt = true;
                    }
                    else if(priceArray[currentIndex+1] < priceArray[currentIndex] && close[currentIndex+1] > priceArray[currentIndex])
                    {
                          if(currentIndex > 0 && close[currentIndex+1] > close[currentIndex])
                          {
                              altStopHunt = true;
                          }
                    }
                }
                else if(priceArray[currentIndex+1] < priceArray[currentIndex] && close[currentIndex+1] > priceArray[currentIndex])
                {
                    if(currentIndex > 0 && close[currentIndex+1] > close[currentIndex])
                    {
                        altStopHunt = true;
                    }
                }
            }

            if(stopHunt)
            {
                PlaySound("alert.wav");
                buffer[currentIndex] = priceArray[currentIndex];
                if(isResistance)
                    Print("StopHuntResistanceBuffer updated at ",time[currentIndex], " with value ", priceArray[currentIndex]);
                else
                    Print("StopHuntSupportBuffer updated at ", time[currentIndex], " with value ", priceArray[currentIndex]);
            }
            if(altStopHunt)
            {
                PlaySound("alert.wav");
                buffer[currentIndex+1] = priceArray[currentIndex+1];
                if(isResistance)
                    Print("Alternative StopHuntResistanceBuffer updated at ",time[currentIndex+1], " with value ", priceArray[currentIndex+1]);
                else
                    Print("Alternative StopHuntSupportBuffer updated at ", time[currentIndex+1], " with value ", priceArray[currentIndex+1]);
            }

            // Once touched, no need to check further for this pivot
            continue;
        }
    }
}