function [pks, pkLocs] = FIND_PEAKS(Y,THD,MPD,xNBRS)
    % ***INCOMPLETE***
    % This function finds local maxima in specified zones.
    %
    % THD = Threshold
    %
    % MPD = Minimum Peak Distance
    %
    % xNBRS = neighbors.
    % This is a zone to the left & right of local yMaxs
    % the algorithm searches in to find other local yMaxs.
    %
    % When X starts at zero, pkLocs is off by 1
    
    if (xNBRS < 1)
        error('xNBRS must be at least 1.');
    end

    % Finding global yMax and its corresponding index xMax
    X=1:length(Y);
    [yMax, xMax] = MAXIMUM(X,Y);

    if ( yMax > THD )
        pkLocs(1,1) = xMax;
        pks(1,1) = yMax;
        pkCount = 2;
    else
        error('Threshold not broken.');
    end

    % Looking to the right of global xMax
    x1 = xMax+MPD-1;
    x2 = x1+xNBRS;
    while (x2 <= X(end));
        [yMax, xMaxLocal] = MAXIMUM2(X,Y,x1,x2);

        if ( yMax > THD )
            pkLocs(1,pkCount) = xMaxLocal;
            pks(1,pkCount) = yMax;
            pkCount = pkCount+1;
        end

        x1 = x2+MPD-1;
        x2 = x1+xNBRS;
    end
       
    % Looking to the left of global xMax
    x2 = xMax-MPD+1;
    x1 = x2-xNBRS;
    while (x1 >= X(1));
        [yMax, xMaxLocal] = MAXIMUM2(X,Y,x1,x2);

        if ( yMax >THD )
            pkLocs(1,pkCount) = xMaxLocal;
            pks(1,pkCount) = yMax;
            pkCount = pkCount+1;
        end

        x2 = x1-MPD+1;
        x1 = x2-xNBRS;
    end
    
    % Sorting results from smallest to largest index
    [pkLocs,pks] = BUBBLE_SORT(pkLocs,pks);
end


