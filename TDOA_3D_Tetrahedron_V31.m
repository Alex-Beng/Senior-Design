%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Joshua Simmons
% August 23, 2015
% Uses Time-Difference-of-Arrival (TDOA) to determine the horizontal
% and elevation azimuths to a 30 kHz SINE wave underwater.
%
% 3D Cartesian co-ordinate system. Sensor geometry is a perfect
% tetrahedron.
%
% The origin is best described by a picture:
%   http://i.stack.imgur.com/YAd7z.gif
%
% Coordinates
%   c1 = (d,0,0)            d = D / sqrt(2)
%   c2 = (0,d,0)
%   c3 = (0,0,d)
%   c4 = (d,d,d)
%   S  = (xS,yS,zS)
%
% Sequence of Events
%  1. Initialization of parameters.
%  2. Source location moves in a predictable manner. The actual time delays
%     are computed from the source position.
%  3. Input signals are constructed using the actual time delays. White
%     Gaussian noise is added along with random DC offsets.
%  4. DC Offsets are removed.
%  5. Cross-correlations (XC) are computed for chan2, chan3, and chan4
%     using chan1 as the reference.
%  6. The maximum y-coordinate of each XC is found and the corresponding
%     x-coordinate is multiplied by the sample time. This is the
%     estimated time delay.
%  7. The time delays are plugged into formulas to find the grid
%     coordinates of the source.
%  8. Once the grid coordinates of the source are found, the horizontal and 
%     vertical azimuths are computed.
%  9. Results are visualized.
%
% Be sure that the support functions (TRAPZ, AVERAGE, MAXIMUM, XCORR) are 
% in the same directory as this file. Or what you can do is add an extra
% path to the folder where the support functions are located on your PC.
% You can do this using the "addpath" MatLab command.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

close all;
clear all;
clc;

% Adding path to support functions
addpath('C:\Users\Joshua Simmons\Desktop\Senior_Design\SONAR Direction Finding Methods\MATLAB Support Functions');

% Global Simulation Parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
trialTotal = 100;
fig1_On = true;  % Time domain signals and cross-correlation functions
fig2_On = true;  % Compass plots
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Source Properties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SNR  = 10;        % Signal to Noise Ratio [dB]
fSce = 30e3;      % Source freq [Hz]
Tsce = 1/fSce;    % Source period [s]
vP   = 1482;      % Propagation Velocity [m/s]
lambda = vP/fSce; % Wavelength [m]
S_Act = [0;0;0];  % Initialization of source location
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Hydrophone Properties
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
D = lambda/4; % Hydrophone spacing [m]
d = D / sqrt(2);  % For coordinates of hydrophones [m]
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% ADC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fS = 1.8e6; % Sample freq [Hz]
tS = 1/fS;  % Sample period [s]

% POWER OF 2 STRONGLY PREFERRED TO TAKE ADVANTAGE OF FFT ACCELERATIONS
N0 = 2^7; % #Samples per frame, RULE OF THUMB IS AT LEAST LAMBDA/4
DATA = zeros(4,N0);  % Raw data
DATA2 = zeros(4,N0); % Cleaned data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% START MAIN LOOP
for trialCount = 1:trialTotal;    
    % Constructing simulated input signals
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Simulating a source moving in the water.
    S_Act(1) = 100*(2*rand()-1);
    S_Act(2) = 100*(2*rand()-1);
    S_Act(3) = 100*(2*rand()-1);

    % Calculating actual azimuths to source
    azimuthH_Act = wrapTo2Pi(atan2(S_Act(2),S_Act(1))) * (180/pi);
    azimuthV_Act = wrapTo2Pi(atan2(S_Act(3),S_Act(1))) * (180/pi);
    
    % Determining the actual time delays
    R1_Act = sqrt( (S_Act(1)-d)^2 + (S_Act(2)  )^2 + (S_Act(3)  )^2 );
    R2_Act = sqrt( (S_Act(1)  )^2 + (S_Act(2)-d)^2 + (S_Act(3)  )^2 );
    R3_Act = sqrt( (S_Act(1)  )^2 + (S_Act(2)  )^2 + (S_Act(3)-d)^2 );
    R4_Act = sqrt( (S_Act(1)-d)^2 + (S_Act(2)-d)^2 + (S_Act(3)-d)^2 );
    
    tD_Act = [0;0;0;0];
    TOA_Act = R1_Act/vP;
    tD_Act(2) = (R2_Act-R1_Act) / vP;
    tD_Act(3) = (R3_Act-R1_Act) / vP;
    tD_Act(4) = (R4_Act-R1_Act) / vP;
    
    % Constructing the input signals from the time delays
    t = 0:tS:(N0-1)*tS; % Time Array [s]    
    DATA(1,:) = cos(2*pi*fSce*t);             % Channel 1 (reference)
    DATA(2,:) = cos(2*pi*fSce*(t+tD_Act(2))); % Channel 2
    DATA(3,:) = cos(2*pi*fSce*(t+tD_Act(3))); % Channel 3
    DATA(4,:) = cos(2*pi*fSce*(t+tD_Act(4))); % Channel 4
    
    % Adding DC offsets (-5 to 5)
    chan = 1;
    while (chan <= 4)
        DC_Offset = (2*rand()-1)*5;
        
        for i=1:N0;
            DATA(chan,i) = DATA(chan,i) + DC_Offset;        
        end
        
        chan = chan+1;
    end    
    
    % Adding Gaussian Noise for increased realism
    DATA = awgn(DATA,SNR);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % Removing DC Offsets    
    chan = 1;
    while (chan <= 4)
        DC_Offset = AVERAGE(t,DATA(chan,:));
        
        for i=1:N0;
            DATA2(chan,i) = DATA(chan,i) - DC_Offset;        
        end
        
        chan = chan+1;
    end   

    % Determining the estimated time delays
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    tD_Est = [0;0;0;0];
    
    [XC12, XC12_Lags] = XCORR( DATA2(1,:), DATA2(2,:) );
    [~,x] = MAXIMUM(XC12_Lags,XC12);
    tD_Est(2) = XC12_Lags(x)*tS;
    
    [XC13, XC13_Lags] = XCORR( DATA2(1,:), DATA2(3,:) );
    [~,x] = MAXIMUM(XC13_Lags,XC13);
    tD_Est(3) = XC13_Lags(x)*tS;
    
    [XC14, XC14_Lags] = XCORR( DATA2(1,:), DATA2(4,:) );
    [~,x] = MAXIMUM(XC14_Lags,XC14);
    tD_Est(4) = XC14_Lags(x)*tS;

    % Determing the location and azimuth to the source
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Calculating estimated source location
    %TOA_Act2 = FIND_TOA(d,tD_Act(2),tD_Act(3),tD_Act(4),vP);
    TOA_Est  = FIND_TOA(d,tD_Est(2),tD_Est(3),tD_Est(4),vP);    
    
    R1_Est = vP*TOA_Est;
    R2_Est = vP*(TOA_Est+tD_Est(2));
    R3_Est = vP*(TOA_Est+tD_Est(3));
    R4_Est = vP*(TOA_Est+tD_Est(4));
    
    S_Est(1) = (-R1_Est^2 + R2_Est^2 + R3_Est^2 - R4_Est^2 + 2*d^2) / (4*d);
    S_Est(2) = ( R1_Est^2 - R2_Est^2 + R3_Est^2 - R4_Est^2 + 2*d^2) / (4*d);
    S_Est(3) = ( R1_Est^2 + R2_Est^2 - R3_Est^2 - R4_Est^2 + 2*d^2) / (4*d);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    % Calculating estimated azimuths to source
    azimuthH_Est = wrapTo2Pi(atan2(S_Est(2),S_Est(1))) * (180/pi);
    azimuthV_Est = wrapTo2Pi(atan2(S_Est(3),S_Est(1))) * (180/pi);
    
    % Visualization        
    stringTrials = sprintf('Trial %0.0f / %0.0f', trialCount, trialTotal);
    
    if (fig1_On == true)
        % Stemming time domain (superimposed) and cross-correlations
        figure(1)
            subplot(2,2,1);
                stem(t*1e6,DATA(1,:),'-b');
                hold on;
                stem(t*1e6,DATA(2,:),'-r');
                stem(t*1e6,DATA(3,:),'-m');
                stem(t*1e6,DATA(4,:),'-g');
                xlabel('Time [\mus]');
                ylabel('Amplitude');
                legend({'Chan1','Chan2','Chan3','Chan4'});
                string111 = sprintf('f_{samp} = %0.2f [MHz]', fS/1e6);
                string112 = sprintf('SNR = %0.0f [dB]', SNR);
                title({string111,string112});
                hold off;
            subplot(2,2,2);         
                stem(XC12_Lags*tS*1e6,XC12,'r');
                hold on;       
                plot(tD_Act(2)*1e6,0,'b.','MarkerSize',20);
                plot(tD_Est(2)*1e6,0,'k.','MarkerSize',20);
                plot(0,0,'w.','MarkerSize',1); 
                string121 = sprintf('td2_{Act} = %f [us]', tD_Act(2)*1e6);
                string122 = sprintf('td2_{Est} = %f [us]', tD_Est(2)*1e6);
                string123 = sprintf('\\Delta td2 = %f [us]', ...
                    (tD_Act(2)-tD_Est(2))*1e6);
                legend({'',string121,string122,string123});
                title('XC_{12}');
                xlabel('Time [\mus]');
                hold off;
            subplot(2,2,3);
                stem(XC13_Lags*tS*1e6,XC13,'m');
                hold on;
                plot(tD_Act(3)*1e6,0,'b.','MarkerSize',20);
                plot(tD_Est(3)*1e6,0,'k.','MarkerSize',20);
                plot(0,0,'w.','MarkerSize',1);
                string131 = sprintf('td3_{Act} = %f [us]', tD_Act(3)*1e6);
                string132 = sprintf('td3_{Est} = %f [us]', tD_Est(3)*1e6);
                string133 = sprintf('\\Delta td3 = %f [us]', ...
                    (tD_Act(3)-tD_Est(3))*1e6);
                legend({'',string131,string132,string133});
                title('XC_{13}');
                xlabel('Time [\mus]');
                hold off;
            subplot(2,2,4);
                stem(XC14_Lags*tS*1e6,XC14,'g');
                hold on;
                plot(tD_Act(4)*1e6,0,'b.','MarkerSize',20);
                plot(tD_Est(4)*1e6,0,'k.','MarkerSize',20);
                plot(0,0,'w.','MarkerSize',1);
                string141 = sprintf('td4_{Act} = %f [us]', tD_Act(4)*1e6);
                string142 = sprintf('td4_{Est} = %f [us]', tD_Est(4)*1e6);
                string143 = sprintf('\\Delta td4 = %f [us]', ...
                    (tD_Act(4)-tD_Est(4))*1e6);
                legend({'',string141,string142,string143});
                title('XC_{14}');
                xlabel('Time [\mus]');
                hold off;
    end
        
    if (fig2_On == true)
        % Comparint actual and estimated source azimuths
        figure(2)
            subplot(2,2,1);
                compass([0 S_Act(1)],[0 S_Act(2)],'-r');
                hold on;
                scalarXY = sqrt( S_Act(1)^2 + S_Act(2)^2 ) / ...
                    sqrt( S_Est(1)^2 + S_Est(2)^2 );
                compass([0 scalarXY*S_Est(1)],[0 scalarXY*S_Est(2)],'-b');
                %view([90, -90]);
                string211 = sprintf('Actual: %0.1f (deg)', azimuthH_Act);
                string212 = sprintf('Estimated: %0.1f (deg)', azimuthH_Est);
                title({stringTrials,'Horizontal Azimuth',string211,string212,''});
                hold off;
                
            subplot(2,2,3);
                compass([0 S_Act(1)],[0 S_Act(3)],'-r');
                hold on;
                scalarXZ = sqrt( S_Act(1)^2 + S_Act(3)^2 ) / ...
                    sqrt( S_Est(1)^2 + S_Est(3)^2 );
                compass([0 scalarXZ*S_Est(1)],[0 scalarXZ*S_Est(3)],'-b');
                %view([90, -90]);
                string221 = sprintf('Actual: %0.1f (deg)', azimuthV_Act);
                string222 = sprintf('Estimated: %0.1f (deg)', azimuthV_Est);
                title({stringTrials,'Vertical Azimuth',string221,string222,''});
                hold off;
                
            subplot(2,2,2);
                plot(S_Act(1),S_Act(2),'r.','MarkerSize',20);
                hold on;
                line([0,S_Act(1)],[0,S_Act(2)],'Color',[1,0,0]);
                line([0,S_Est(1)],[0,S_Est(2)],'Color',[0,1,0]);
                grid on;
                xlim([-100,100]);
                ylim([-100,100]);
                hold off;
            subplot(2,2,4);
                plot(S_Act(1),S_Act(3),'r.','MarkerSize',20);
                hold on;
                line([0,S_Act(1)],[0,S_Act(3)],'Color',[1,0,0]);
                line([0,S_Est(1)],[0,S_Est(3)],'Color',[0,1,0]);
                grid on;
                xlim([-100,100]);
                ylim([-100,100]);
                title('XZ Plane');
                hold off;
                
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    pause(0.5);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
