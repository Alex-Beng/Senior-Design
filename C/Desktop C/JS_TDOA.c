#include "js_tdoa.h"

double complex BPF (double complex Y[], int yLength, double H[]) {
    // Status: UNTESTED
    //
    // Description: Applies a digital brick wall bandpass filter to a complex signal Yf.

    for (int i=0; i<yLength; i++) { Y[i] = H[i] * Y[i]; }

    return Y;
}

void PingerLocation (double PingerLoc[], double R[], double d) {
    // Status: UNTESTED
    //
    // Description: Computes the estimated pseudo-location of the pinger.

    PingerLoc[0] = (R[3]*R[3]-R[1]*R[1])/(4.0*d);
    PingerLoc[1] = (R[2]*R[2]-R[0]*R[0])/(4.0*d);
    PingerLoc[2] = sqrt(R[0]*R[0]-PingerLoc[0]*PingerLoc[0]-(PingerLoc[1]-d)*(PingerLoc[1]-d));

    return;
}

void SphereRadii (double R[], double tD2, double tD3, double tD4, double TOA, double vP) {
    // Status: UNTESTED
    //
    // Description: Computes the spherical radii.

    R[0] = vP*(TOA);
    R[1] = vP*(TOA+tD2);
    R[2] = vP*(TOA+tD3);
    R[3] = vP*(TOA+tD4);

    return;
}
