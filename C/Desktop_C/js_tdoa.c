#include "js_tdoa.h"

void AdjustPGA (double* f, double _Complex* chanx_f, double powerMin, double powerMax) {
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Calculates the signal power and adjusts the gain of the ADC PGA accordingly.
    *
    *   Status: incomplete
    *
    *   Notes:
    *       1. Will have to wait until familarization with ADC to be implemented.
    */

    double power = 0.0;

    power = SignalPower(f,chanx_f);

    if (power >= powerMax) {
        printf("\nDecreased PGA Gain.");
    }
    else if (power <= powerMin) {
        printf("\nIncreased PGA Gain.");
    }
    else;

    return;
}

void CalcPingerAzimuths(double* pingerLocs, double* azimuthH, double* azimuthV1, double* azimuthV2) {
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Calculates the pinger azimuths from its Cartesian coordinates.
    *
    *   Status: untested
    *
    *   Notes: NONE! 
    */

    // Determining pinger azimuths in radians
    *azimuthH  = atan2(   pingerLocs[2],pingerLocs[1]);
    *azimuthV1 = atan2(   pingerLocs[3],pingerLocs[1]);
    *azimuthV2 = atan2(-1*pingerLocs[3],pingerLocs[1]);

    // Wrapping angle [0,2pi]
    *azimuthH  = WrapTo2Pi(*azimuthH);
    *azimuthV1 = WrapTo2Pi(*azimuthV1);
    *azimuthV2 = WrapTo2Pi(*azimuthV2);
    
    // Converting to degrees
    *azimuthH  = (*azimuthH)  * (180.0/pi);
    *azimuthV1 = (*azimuthV1) * (180.0/pi);
    *azimuthV2 = (*azimuthV2) * (180.0/pi);

    return;
}

void CalcDiamondPingerLocation(double d, double td2, double td3, double td4, double TOA1, double vP, double* pingerLocs){
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Calculates the pinger coordinates for a diamond sensor configuration using TDOA.
    *
    *   Status: untested
    *
    *   Notes: NONE!
    */

    double R1 = 0.0;
    double R2 = 0.0;
    double R3 = 0.0;
    double R4 = 0.0;

    R1 = vp*(TOA1);
    R1 = vp*(TOA1+td2);
    R1 = vp*(TOA1+td3);
    R1 = vp*(TOA1+td4);

    // Checking for complex solutions
    if ( R1 > 0 && R2 > 0 && R3 > 0 && R4 > 0 {
        R1 = sqrt(R1);
        R2 = sqrt(R2);
        R3 = sqrt(R3);
        R4 = sqrt(R4);

        *pingerLocs[1] = (R4*R4 - R2*R2) / (4.0*d);
        *pingerLocs[2] = (R3*R3 - R1*R1) / (4.0*d);
        *pingerLocs[3] = sqrt( R1*R1 - pingerLocs[1]*pingerLocs[1] - (pingerLocs[2]-d)*(pingerLocs[2]-d) );
    }
    else {
        printf("\nWarning in CalcDiamondPingerLocation(). Sphere radii are complex.");
        printf("\nThe last REAL sphere radii will be used.");
    }

    return;
}

double CalcTimeDelay (double fADC, int N0, double* chan1_t, double* chanx_t, double threshold, double TOA1, int lagBounds, int pkCounterMax) {
     /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Computes the time delay for TDOA directional finding via cross-correlation. 
    *
    *   Status: untested
    *
    *   Notes:
    *       1. lagBounds may become a variable and placed inside this function. This would happen if fPinger becomes a variable. 
    */

    double tD = 0.0;
    double tD_BW = 0.0;
    double TOA234 = 0.0;

    double tD_XCs[1+pkCounterMax];
    double XC[2*(1+lagBounds)];
    double XC_Lags[2*(1+lagBounds)];

    tD_XCs[0] = pkCounterMax;
    XC[0] = 2*lagBounds+1;
    XC_Lags[0] = 2*lagBounds+1;

    char* dir = "LR"; // Head triggered. Switch to "RL" for tail triggered. 
    TOA234 = BreakWall(dir,chanx_t,threshold) / fADC;

    tD_BW = TOA1 - TOA234; // Head triggered. Switch to TOA234 - TOA1 for tail triggered. 

    XCorr(chan1_t,chanx_t,lagBounds,XC_Lags,XC);
    LocalMaxima(XC,2,threshold,pkLocs);  // Adjust the second value (iMPD) when fPinger is a variable

    for ( int i=1; i <= pkCounterMax; i++) {
        if ( pkLocs[i] > 1 ) {
            tD_XCs[i] = XC_Lags[pkLocs[i]] / fADC;
        }
        else {
            tD_XCs[i] = -10*N0/fADC;
        }
    }

    tD = Compare(tD_BW,tD_XCs);

    return tD;
}

void CenterWindow (double fADC, int N0, double* chan1_t, double threshold, double* PRT, double *TOA1) {
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Fine adjusts the PRT to maintain pinger synchronization. 
    *
    *   Status: untested
    *
    *   Notes: NONE! 
    */

    double tError = 0.0;
    double tCenter = (N0/2+1) / fADC;

    char* dir = "LR";
    *TOA1 = BreakWall(dir,chan1_t,threshold) / fADC;

    if ( TOA1 > 0 ) {
        tError = tCenter - TOA1;

        if ( TOA1 > tCenter ) {
            *PRT -= tError;
        }
        else {
            *PRT += tError;
        }
    }
    else {
        printf("\nWarning in CenterWindow(). BreakWall() failed to trigger.");
    }

    return;
}

void DelaySampleTrigger(double PRT) {
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description:
    *
    *   Status: incomplete
    *
    *   Notes: NONE! 
    */

    printf("\nDelayed by %f[ms]", PRT*1E+3);

    return;
}

void SampleAllChans (double fADC, int N0, double* chan1_t, double* chan2_t, double* chan3_t, double* chan4_t) {
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Communicates with the ADC to sample all channels asynchrously. 
    *
    *   Status: incomplete
    *
    *   Notes:
    *       1. How to append file names?
    */

    // Simulating ADC sampling
    ReadCSV("/Users/betio32/Desktop/TDOA_Chan1_SimData.CSV",chan1_t);
    ReadCSV("/Users/betio32/Desktop/TDOA_Chan2_SimData.CSV",chan2_t);
    ReadCSV("/Users/betio32/Desktop/TDOA_Chan3_SimData.CSV",chan3_t);
    ReadCSV("/Users/betio32/Desktop/TDOA_Chan4_SimData.CSV",chan4_t);

    printf("\nSampled All Channels.");

    return;
}

void SyncPinger (double fADC, int N0, double* chan1_t, double* chan2_t, double* chan3_t, double* chan4t, 
    double _Complex H, double threshold, double PRT_Min, double* PRT, int* pingerSynced) {
    /*
    *   Author: Joshua Simmons
    *
    *   Date: September 2015
    *
    *   Description: Synchronizes processor with pinger by changing PRT. 
    *
    *   Status: untested
    *
    *   Notes: NONE! 
    *
    *   % The start of the present frame globally
    *   tGlobal = tADC*(iGlobal-1);
    *
    *   % Adjusting the PRT
    *   if (headCount > 1 && headCount < 12)
    *       PRT_Array(mod(headCount,10)+1) = tGlobal - tGlobalLast;
    *       PRT = median(PRT_Array);
    *   end
    *
    *   if (headCount < 12) % Delaying by PRT
    *       tGlobalLast = tGlobal;
    *       tGlobal = tGlobal + PRT;
    *       else % Delaying so that the heads are in the center of the frame
    *       tError = tHeads - tADC*(frameSize/2);
    *       tGlobal = tGlobal + PRT + tError + tPing/4;   
    *   end
    */

    char* dir = "LR";
    int triggerCount = 0;
    int triggerCountPRT_Max = 13;
    int triggerCountCW_Max = 16;
    double triggerDelay = 0.9*tPW_Min; // Minimal expected pulse width
    double t_Trigger1 = 0.0;
    double t_Trigger2 = 0.0;
    double tLowerBound = 0.1*N0/fADC;
    double tUpperBound = 0.9*N0/fADC;
    double PRT_Array[1+10];

    PRT_Array[1] = 10;

    while ( pingerSynced == FALSE ) {

        printf("\nAttemping to synchronize with pinger...");
        
        SampleAllChans(fADC, N0, chan1_t, chan2_t, chan3_t, chan4_t);
        FFT(chan1_t,chanx_f);

        AdjustPGA(f,chanx_f, powerMin, powerMax);

        // Bandpass Filtering Channel 1
        for (int i=1; i <= N0; i++) {
            chanx_f[i] = chanx_f[i] * H[i];
        }

        /*
        *   Determining fPinger
        *
        *   iMax = Max(chanx_f,i_fCMHC,i_fCPHC);    // fCenter Minus/Plus halfChan
        *
        *   if ( iMax > 0 && cabs(chanx_f[iMax]) > threshold ) {
        *       fPinger = f[iMax];
        *   }
        *   else
        */

        iFFT(chanx_f,chan1_t);

        t_Trigger2 = BreakWall(dir,chan1_t,threshold) / fADC;

        // If BreakWall fails to trigger then t_Trigger2 < 0
        if ( t_Trigger2 > tLowerBound && t_Trigger2 < tUpperBound ) {

            printf("\nSyncPinger() detected signal.");

            triggerCount++;
            PRT = t_Trigger2 - t_Trigger1;
            t_Trigger1 = t_Trigger2;

            // Calculating Median PRT
            if ( triggerCount < triggerCountPRT_Max ) {
                triggerDelay = PRT;
                PRT_Array[triggerCount%10] = PRT;

                if ( triggerCount > 2 ) {
                    PRT = Median(PRT_Array);
                    triggerDelay = PRT;
                }
                else;
            }
            // Centering Window
            else if ( triggerCount >= triggerCountPRT_Max ) {
                CenterWindow(fADC,N0,chan1_t,threshold,PRT,TOA1);
                triggerDelay = PRT;

                if ( triggerCount >= triggerCountCW_Max ) {
                    *pingerSynced = TRUE;
                }
                else;
            }
            else;
        }
        else;

        DelaySampleTrigger(triggerDelay);
    }

    printf("\nSuccessfully synchronized with the pinger.");

    return;
}
