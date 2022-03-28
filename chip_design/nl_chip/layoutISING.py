# -*- coding: utf-8 -*-
"""
Created on Tue Feb 6 10:37:55 2022

@author: rsekine
"""

# import nazca as nd
import numpy as np
from phidl import Device, Layer, LayerSet, make_device
import phidl.geometry as pg
import phidl.routing as pr
import phidl.utilities as pu
from phidl.device_layout import Path, CrossSection, _rotate_points


import phidl.path as pp
import numpy as np

from scipy.constants import pi, c


def setup_layers():
    ls = LayerSet() # Create a blank LayerSet
    ls.add_layer(name = 'ChipBoundary', gds_layer = 99, gds_datatype = 0,  description = 'Chip boundary', color = 'darkblue', alpha = 0.1)
    ls.add_layer(name = 'Ebeamfield', gds_layer = 0, gds_datatype = 0,  description = 'Ebeam Field', color = 'ghostwhite', alpha = 0.01)
    ls.add_layer(name = 'Annotation', gds_layer = 97, gds_datatype = 0,  description = 'Description', color = 'black', alpha = 0.4)
    ls.add_layer(name = 'PolingE', gds_layer = 10, gds_datatype = 0,  description = 'Poling Electrodes', color = 'goldenrod', alpha = 0.7)
    ls.add_layer(name = 'MarkerM', gds_layer = 20, gds_datatype = 0,  description = 'Marker Protection', color = 'PaleGreen', alpha = 0.2)
    ls.add_layer(name = 'Waveguides', gds_layer = 30, gds_datatype = 0,  description = 'Ridge waveguide', color = 'crimson', alpha = 0.8)
    ls.add_layer(name = 'Bot_EOM', gds_layer = 40, gds_datatype = 0,  description = 'Bottom EOM Electrodes', color = 'gold', alpha = 0.8)
    ls.add_layer(name = 'Vias', gds_layer = 50, gds_datatype = 0,  description = 'Vias to etch SiO2 cladding', color = 'lightskyblue', alpha = 0.7)
    ls.add_layer(name = 'Pt', gds_layer = 60, gds_datatype = 0,  description = 'Pt for heaters', color = 'blue', alpha = 0.8) #silver
    ls.add_layer(name = 'Wirebond', gds_layer = 70, gds_datatype = 0,  description = 'Electrodes routing to bonding pads', color = 'palegoldenrod', alpha = 0.2)

    return ls

def waveguide(width = 1, length = 10, layer = 1):
    '''
    Parameters
    ----------
    width : FLOAT, optional
        WIDTH OF THE WAVEGUIDE. The default is 1.
    length : FLOAT, optional
        LENGTH OF THE WAVEGUIDE. The default is 10.
    layer : INT, optional
        LAYER. The default is 1.

    Returns
    -------
    WG : DEVICE (PHIDL)
        WAVEGUIDE OBJECT

    '''
    WG = Device('Waveguide')
    WG.add_polygon( [(0, 0), (length, 0), (length, width), (0, width)] , layer=layer)
    WG.add_port(name = 1, midpoint = [0,width/2], width = width, orientation = 180)
    WG.add_port(name = 2, midpoint = [length,width/2], width = width, orientation = 0)
    return WG

def global_markers(layer_marker=10, layer_mask=20):
    D = Device('Global Markers')
    R = pg.rectangle(size=(20,20), layer=1)
    a = D.add_array(R, columns = 6, rows = 6,  spacing = (100, 100))
    a.move([-260, -260]) #Center of the array
    
    R = pg.rectangle(size=(20,20), layer=1)
    a = D.add_array(R, columns = 6, rows = 6,  spacing = (100, 100))
    a.move([-260, -260]) #Center of the array
    
    #Add marker cover
    cover = pg.bbox(bbox = a.bbox, layer=layer_mask)
    D << pg.offset(cover, distance=100, layer=layer_mask)
    return D

def chip(size = (13000, 18000), keepout=2000, name='chip01', text_size=250,
         layer_text=10, layer=99):
    k = keepout
    DX = size[0]
    DY = size[1]
    OUT = pg.rectangle(size=size, layer=layer)
    IN = pg.rectangle(size=(DX-2*k, DY-2*k), layer=layer)
    IN.move((k,k))
    
    CHIP = pg.boolean(A = OUT, B = IN, operation = 'A-B', layer=layer)
    
    #Add name
    L = pg.text(text=name, size=text_size, layer=1, justify='center')
    CHIP.add_ref(L).move((DX/2,k-text_size-200))
    
    #Add markers
    M = global_markers()
    offset = 110
    CHIP.add_ref(M).move([k-offset,k-offset])
    CHIP.add_ref(M).move([DX-k+offset-3000,k-offset])
    CHIP.add_ref(M).move([k-offset,DY-k+offset])
    CHIP.add_ref(M).move([DX-k+offset-3000,DY-k+offset])
    
    return CHIP
  
def poling_region(length=4000, period=5, dutycycle=0.4, gap=25,
                  Lfinger=50, layer=10, pad_width=50):
    
    #Calculations
    Wfinger = period*dutycycle
    Nfinger = int(length/period) + 1
    length = Nfinger*period - (1-dutycycle)*period

    P = Device('Poling Electrodes')
    
    #Positive side
    R = pg.rectangle([length, pad_width], layer=layer)
    F = pg.rectangle([Wfinger, Lfinger], layer=layer)
    P << R
    a = P.add_array(F, columns=Nfinger, rows=1, spacing=(period,0))
    a.move([0, pad_width])
    
    #Negative side
    R2 = pg.rectangle([length, pad_width], layer=layer)
    r2 = P.add_ref(R2)
    r2.move([0, pad_width+Lfinger+gap])
    
    return P

def contact_pads(size = (150,150), label='', label_size = 50, layer=10):
    # P = Device('Pad')
    R = pg.rectangle(size, layer)
    if label != '':
        L = pg.text(label, label_size, layer=layer)
        L.move([10,10])
        P = pg.boolean(A = R, B = L, operation = 'A-B', layer=layer)
    else:
        P = R
    return P



def _fresnel(R0, s, num_pts, n_iter=8):
    """ Fresnel integral using a series expansion """
    t = np.linspace(0,s/(np.sqrt(2)*R0), num_pts)
    x = np.zeros(num_pts)
    y = np.zeros(num_pts)

    for n in range(0,n_iter):
      x += (-1)**n * t**(4*n+1)/(np.math.factorial(2*n) * (4*n+1))
      y += (-1)**n * t**(4*n+3)/(np.math.factorial(2*n+1) * (4*n+3))

    return np.array([np.sqrt(2)*R0*x, np.sqrt(2)*R0*y])

def mod_euler(radius = 3, angle = 90, p = 1.0, use_eff = False, num_pts = 720):
    """ Create an Euler bend (also known as "racetrack" or "clothoid" curves)
    that adiabatically transitions from straight to curved.  By default,
    `radius` corresponds to the minimum radius of curvature of the bend.
    However, if `use_eff` is set to True, `radius` corresponds to the effective
    radius of curvature (making the curve a drop-in replacement for an arc). If
    p < 1.0, will create a "partial euler" curve as described in Vogelbacher et.
    al. https://dx.doi.org/10.1364/oe.27.031394
    Parameters
    ----------
    radius : int or float
        Minimum radius of curvature
    angle : int or float
        Total angle of curve
    p : float
        Proportion of curve that is an Euler curve
    use_eff : bool
        If False: `radius` corresponds to minimum radius of curvature of the bend
        If True: The curve will be scaled such that the endpoints match an arc
        with parameters `radius` and `angle`
    num_pts : int
        Number of points used per 360 degrees
    Returns
    -------
    Path
        A Path object with the specified Euler curve
    """
    if (p < 0) or (p > 1):
        raise ValueError('[PHIDL] euler() requires argument `p` be between 0 and 1')
    if p == 0:
        P = arc(radius = radius, angle = angle, num_pts = num_pts)
        P.info['Reff'] = radius
        P.info['Rmin'] = radius
        return P

    if angle < 0:
        mirror = True
        angle = np.abs(angle)
    else:
        mirror = False

    R0 = 1
    alpha = np.radians(angle)
    Rp = R0 / (np.sqrt(p*alpha))
    sp = R0 * np.sqrt(p*alpha)
    s0 = 2*sp + Rp*alpha*(1-p)
    num_pts = abs(int(num_pts*angle/360))
    num_pts_euler = int(np.round(sp/(s0/2)*num_pts))
    num_pts_arc = num_pts - num_pts_euler

    xbend1, ybend1 = _fresnel(R0, sp, num_pts_euler)
    xp, yp = xbend1[-1], ybend1[-1]

    dx = xp - Rp*np.sin(p*alpha/2)
    dy = yp - Rp*(1-np.cos(p*alpha/2))

    s = np.linspace(sp, s0/2, num_pts_arc)
    xbend2 = Rp*np.sin((s-sp)/Rp + p*alpha/2) + dx
    ybend2 = Rp*(1 - np.cos((s-sp)/Rp + p*alpha/2)) + dy

    x = np.concatenate([xbend1, xbend2[1:]])
    y = np.concatenate([ybend1, ybend2[1:]])
    points1 = np.array([x,y]).T
    points2 = np.flipud(np.array([x,-y]).T)
    
    points2 = _rotate_points(points2, angle-180)
    points2 += -points2[0,:] + points1[-1,:]

    points = np.concatenate([points1[:-1],points2])

    # Find y-axis intersection point to compute Reff
    start_angle = 180*(angle<0)
    end_angle = start_angle + angle
    dy = np.tan(np.radians(end_angle-90)) * points[-1][0]
    Reff = points[-1][1] - dy
    Rmin = Rp

    # Fix degenerate condition at angle == 180
    if np.abs(180-angle) < 1e-3:
        Reff = points[-1][1]/2

    # Scale curve to either match Reff or Rmin
    if use_eff == True:
        scale = radius/Reff
    else:
        scale = radius/Rmin
    points *= scale
    
    #change to return last point of bend
    array_length = len(points)
    last_element = points[array_length - 1]
    last_coord = last_element-points[0]


    P = Path()
    # Manually add points & adjust start and end angles
    P.points = points
    P.start_angle = start_angle
    P.end_angle = end_angle
    P.info['Reff'] = Reff*scale
    P.info['Rmin'] = Rmin*scale
    if mirror == True:
        P.mirror((1,0))
    return P, last_coord

def eom_sym(wg_width,length,middle_e_width,e_e_gap,chip_width,offset,radius):
    euler_y = mod_euler(radius = radius, angle = -45)[1][1]
    euler_x = mod_euler(radius = radius, angle = -45)[1][0]
    wg_wg_sep = (middle_e_width + e_e_gap)/2 - 2*euler_y
    straight = wg_wg_sep*np.sqrt(2)
    if wg_wg_sep < 0:
        raise Exception("middle_e_width is set too small with respect to Euler radius")
    
    left = chip_width/2- length/2 - 2*euler_x - wg_wg_sep + offset
    right = left
    
    P1 = Path()
    P1.append( pp.straight(length = left) )          
    P1.append( mod_euler(radius = radius, angle = -45)[0] )
    P1.append( pp.straight(length = straight) )
    P1.append( mod_euler(radius = radius, angle = 45)[0] )
    P1.append( pp.straight(length = length) )
    P1.append( mod_euler(radius = radius, angle = 45)[0] )
    P1.append( pp.straight(length = straight) )
    P1.append( mod_euler(radius = radius, angle = -45)[0] )
    P1.append( pp.straight(length = right) ) 
    
    
    X = CrossSection()
    X.add(width = wg_width, offset = 0, layer = 1)
    waveguide_device1 = P1.extrude(X)
    
    E = Device('EOM_GHz')
    b1 = E.add_ref(waveguide_device1)
    b2 = E.add_ref(waveguide_device1)
    b2.mirror((0,0),(1,0))
    
    
    square = middle_e_width*0.6
    square_rec_offset = (middle_e_width - square)/2
    e_left = left+2*euler_x+wg_wg_sep
    e_right = left+2*euler_x+wg_wg_sep+length-square
    
    #side_e_width
    R = pg.rectangle(size=(length,middle_e_width), layer=10)
    S = pg.rectangle(size=(square,square), layer=2)
    
    #top electrode
    h_top = middle_e_width/2 + e_e_gap
    E.add_ref(R).move([e_left,h_top])
    E.add_ref(S).move([e_left,h_top + square_rec_offset])
    E.add_ref(S).move([e_right,h_top + square_rec_offset])
    
    #middle electrode
    E.add_ref(R).move([e_left,-middle_e_width/2])
    E.add_ref(S).move([e_left,-square/2])
    E.add_ref(S).move([e_right,-square/2])
    
    
    #bottom electrode
    h_bot = -3*middle_e_width/2 - e_e_gap
    E.add_ref(R).move([e_left,h_bot])
    E.add_ref(S).move([e_left,h_bot + square_rec_offset])
    E.add_ref(S).move([e_right,h_bot + square_rec_offset])
    #E << R
    return E

def bonding_pads(margin, pad, chip_width, chip_height):
    num = 18
    sep = (chip_width - 2*margin)/num
    P = pg.rectangle(size=(pad,pad), layer=3).move([margin,margin])
    P << pg.rectangle(size=(pad,pad), layer=3).move([margin,chip_height-margin-pad])
    for i in range(1,int(num/2)):
        P << pg.rectangle(size=(pad,pad), layer=3).move([margin+i*sep,margin])
        P << pg.rectangle(size=(pad,pad), layer=3).move([margin+i*sep,chip_height-margin-pad])
        
    E = Device('bonding_pads')
    b1 = E.add_ref(P)
    b2 = E.add_ref(P)
    b2.mirror((chip_width/2, chip_height),(chip_width/2, 0))        

    return E, sep

def connectPad(middle_e_width, chip_width, chip_height, radius,length,e_e_gap,setpos,side_electrode_width,y_pos):
    T = Device('connections')
    x2 = (chip_width - length )/2 + middle_e_width
    h_bot = -middle_e_width/2 - side_electrode_width/2 - e_e_gap + y_pos
    T << connect(x2,h_bot, middle_e_width, chip_width, chip_height, 'b', radius,length,e_e_gap,setpos)
    h_mid =  y_pos
    T << connect(x2,h_mid, middle_e_width, chip_width, chip_height, 'm', radius,length,e_e_gap,setpos)
    h_top = middle_e_width/2 + e_e_gap + y_pos + side_electrode_width/2
    T << connect(x2,h_top, middle_e_width, chip_width, chip_height, 't', radius,length,e_e_gap,setpos)
    return T

def connect(x2, y2, middle_e_width, chip_width, chip_height, pos, radius,length,e_e_gap,setpos):
    mm = 10**3
    um = 1 
    
    M = Path()
    # Dimensions
    margin = 0.5*mm
    to_pad_term = 0.1*mm
    pad = 50*um
    pitch = 100*um
    side_e_width = middle_e_width*2
    rad_gap = e_e_gap + middle_e_width/2 + side_e_width/2
    
    if pos == 't':
        Rt = radius + rad_gap*2
    elif pos == 'm':
        Rt = radius + rad_gap
    else:
        Rt = radius
    
    if setpos == 't':
        set_bias = 0.6*mm
    elif setpos == 'm':
        set_bias = 0.3*mm
    else:
        set_bias = 0
    
    x1 = (chip_width - length )/2 - Rt - set_bias
    y1 = margin + to_pad_term
    points = np.array([(x1,y1), (x1,y2), (x2,y2)])    
    points = rotate90(points)
        
    M = pp.smooth(
        points = points,
        radius = Rt,
        corner_fun = pp.arc,
        )
    M.rotate(90)
    
    X = CrossSection()
    if pos == 'm':
        X.add(width = middle_e_width, offset = 0, layer = 3)
    else:
        X.add(width = side_e_width, offset = 0, layer = 3)
    
    L = M.extrude(X) #Left Trace
    
    
    
    if pos == 'm':
        # adding pads
        S = pg.rectangle(size=(pad,pad), layer=3)
        L.add_ref(S).move([x1-pad/2, margin])
        L.add_ref(S).move([x1-pad/2-pitch, margin])
        L.add_ref(S).move([x1-pad/2+pitch, margin])
        
        xm1 = x1 - middle_e_width/2
        xm2 = x1 + middle_e_width/2
        xm3 = x1 + pad/2
        xm4 = x1 - pad/2
        xpts = (xm1,xm2,xm3,xm4)
        ypts = (y1,y1,margin+pad,margin+pad)
        L.add_polygon( [xpts, ypts], layer = 3)
       
        xt1 = xm1 + middle_e_width + e_e_gap
        xt2 = xt1 + side_e_width
        xt3 = xm3 + pitch
        xt4 = xm4 + pitch
        xpts = (xt1,xt2,xt3,xt4)
        ypts = (y1,y1,margin+pad,margin+pad)
        L.add_polygon( [xpts, ypts], layer = 3)
        
        xb1 = xm1 - side_e_width - e_e_gap
        xb2 = xm1 - e_e_gap
        xb3 = xm3 - pitch
        xb4 = xm4 - pitch
        xpts = (xb1,xb2,xb3,xb4)
        ypts = (y1,y1,margin+pad,margin+pad)
        L.add_polygon( [xpts, ypts], layer = 3)

    
    R = pg.copy(L) # Right Trace
    R.mirror((chip_width/2, chip_height), (chip_width/2, 0))
    
    D = Device('trace')
    D << L
    D << R
    return D

def dc_pad(x,y,pad,name):
    R = pg.rectangle(size = (pad, pad), layer = 70)
    
    D = Device()
    rect1 = D << R
    rect1.move([x,y])
    
    text_size = 20
    L = pg.text(text=name, size=text_size, layer=97, justify='center')
    D.add_ref(L).move((x+pad/3,y))
    
    return D

def wb_pad(x,y,pad,name):
    R = pg.rectangle(size = (pad, pad-0.5), layer = 70)
    
    D = Device()
    rect1 = D << R
    rect1.move([x,y])
    
    text_size = 20
    L = pg.text(text=name, size=text_size, layer=97, justify='center')
    D.add_ref(L).move((x+pad/3,y))
    
    return D

def triplet_pad(x,y,pad,pad_g,elec_m,elec,elec_s,e_e_gap,pos):
    R = pg.rectangle(size = (pad, pad), layer = 70)
    
    D = Device()
    rect1 = D << R
    rect2 = D << R
    rect3 = D << R
    rect1.move([x,y])
    rect2.move([x-pad_g,y])
    rect3.move([x+pad_g,y])
    
    #middle connector pad
    xm1 = x - elec_m/2
    xm2 = x - pad/2
    xm3 = x + pad/2
    xm4 = x + elec_m/2    
    xpts = (xm1+pad/2,xm2+pad/2,xm3+pad/2,xm4+pad/2)
    ypts = (y+pad+elec,y+elec,y+elec,y+pad+elec)
    if pos == 'u':
        ypts = (y-elec,y,y,y-elec)
    D.add_polygon( [xpts, ypts], layer = 70)
    
    text_size = 20
    L = pg.text(text='S', size=text_size, layer=97, justify='center')
    D.add_ref(L).move((x+pad/3,y))
    
    #left connector pad
    xm1 = x - elec_m/2 - e_e_gap - elec_s
    xm2 = x - pad/2 - pad_g
    xm3 = x + pad/2 - pad_g
    xm4 = x - elec_m/2 - e_e_gap    
    xpts = (xm1+pad/2,xm2+pad/2,xm3+pad/2,xm4+pad/2)
    ypts = (y+pad+elec,y+elec,y+elec,y+pad+elec)
    if pos == 'u':
        ypts = (y-elec,y,y,y-elec)
    D.add_polygon( [xpts, ypts], layer = 70)
    
    L = pg.text(text='G', size=text_size, layer=97, justify='center')
    D.add_ref(L).move((x-pad_g++pad/3,y))
        
    #left connector pad
    xm1 = x + elec_m/2 + e_e_gap 
    xm2 = x + pad/2 + pad_g - pad
    xm3 = x + pad/2 + pad_g
    xm4 = x + elec_m/2 + e_e_gap + elec_s 
    xpts = (xm1+pad/2,xm2+pad/2,xm3+pad/2,xm4+pad/2)
    ypts = (y+pad+elec,y+elec,y+elec,y+pad+elec)
    if pos == 'u':
        ypts = (y-elec,y,y,y-elec)
    D.add_polygon( [xpts, ypts], layer = 70) 
    
    L = pg.text(text='G', size=text_size, layer=97, justify='center')
    D.add_ref(L).move((x+pad_g++pad/3,y))
    
    return D

def connection_DR(x1,y1,x2,y2,elec_m,elec_s,e_e_gap,Rt): #down right
    
    D = Device()
    
    x1t = x1+elec_m/2+elec_s/2+e_e_gap
    x1b = x1-elec_m/2-elec_s/2-e_e_gap
    
    y2t = y2+elec_m/2+elec_s/2+e_e_gap
    y2b = y2-elec_m/2-elec_s/2-e_e_gap

    points = np.array([(x1,y1), (x1,y2), (x2,y2)])  
    points_t = np.array([(x1t,y1), (x1t,y2t), (x2,y2t)])  
    points_b = np.array([(x1b,y1), (x1b,y2b), (x2,y2b)])  
    
    M = pp.smooth(
        points = points,
        radius = Rt+elec_m/2+elec_s/2+e_e_gap,
        corner_fun = pp.arc,
        )
    M.rotate(-90, center=(x1,y1))
    
    Mt = pp.smooth(
        points = points_t,
        radius = Rt,
        corner_fun = pp.arc,
        )
    Mt.rotate(-90, center=(x1t,y1))
    
    Mb = pp.smooth(
        points = points_b,
        radius = Rt+2*(elec_m/2+elec_s/2+e_e_gap),
        corner_fun = pp.arc,
        )
    Mb.rotate(-90, center=(x1b,y1))
    
    
    X = CrossSection()
    X.add(width = elec_m, offset = 0, layer = 70)
    Xt = CrossSection()
    Xt.add(width = elec_s, offset = 0, layer = 70)
    Xb = CrossSection()
    Xb.add(width = elec_s, offset = 0, layer = 70)
        
    L = M.extrude(X) #Left Trace
    Lt = Mt.extrude(Xt) #Left Trace
    Lb = Mb.extrude(Xb) #Left Trace 
    
    D << L
    D << Lt
    D << Lb
    return D

def connection_RD(x1,y1,x2,y2,elec_m,elec_s,e_e_gap,Rt): #right down
    
    D = Device()
    
    y1t = y1+elec_m/2+elec_s/2+e_e_gap
    y1b = y1-elec_m/2-elec_s/2-e_e_gap
    
    x2t = x2+elec_m/2+elec_s/2+e_e_gap
    x2b = x2-elec_m/2-elec_s/2-e_e_gap

    points = np.array([(x1,y1), (x2,y1), (x2,y2)])  
    points_t = np.array([(x1,y1t), (x2t,y1t), (x2t,y2)])  
    points_b = np.array([(x1,y1b), (x2b,y1b), (x2b,y2)])  
    
    M = pp.smooth(
        points = points,
        radius = Rt+elec_m/2+elec_s/2+e_e_gap,
        corner_fun = pp.arc,
        )
    
    Mt = pp.smooth(
        points = points_t,
        radius = Rt+2*(elec_m/2+elec_s/2+e_e_gap),
        corner_fun = pp.arc,
        )
    
    Mb = pp.smooth(
        points = points_b,
        radius = Rt,
        corner_fun = pp.arc,
        )
    
    
    X = CrossSection()
    X.add(width = elec_m, offset = 0, layer = 70)
    Xt = CrossSection()
    Xt.add(width = elec_s, offset = 0, layer = 70)
    Xb = CrossSection()
    Xb.add(width = elec_s, offset = 0, layer = 70)
        
    L = M.extrude(X) #Left Trace
    Lt = Mt.extrude(Xt) #Left Trace
    Lb = Mb.extrude(Xb) #Left Trace 
    
    D << L
    D << Lt
    D << Lb
    return D

def connection_RU(x1,y1,x2,y2,elec_m,elec_s,e_e_gap,Rt): #right down
    
    D = Device()
    
    y1t = y1-elec_m/2-elec_s/2-e_e_gap
    y1b = y1+elec_m/2+elec_s/2+e_e_gap
    
    x2t = x2+elec_m/2+elec_s/2+e_e_gap
    x2b = x2-elec_m/2-elec_s/2-e_e_gap

    points = np.array([(x1,y1), (x2,y1), (x2,y2)])  
    points_t = np.array([(x1,y1t), (x2t,y1t), (x2t,y2)])  
    points_b = np.array([(x1,y1b), (x2b,y1b), (x2b,y2)])  
    
    M = pp.smooth(
        points = points,
        radius = Rt+elec_m/2+elec_s/2+e_e_gap,
        corner_fun = pp.arc,
        )
    
    Mt = pp.smooth(
        points = points_t,
        radius = Rt+2*(elec_m/2+elec_s/2+e_e_gap),
        corner_fun = pp.arc,
        )
    
    Mb = pp.smooth(
        points = points_b,
        radius = Rt,
        corner_fun = pp.arc,
        )    
    
    X = CrossSection()
    X.add(width = elec_m, offset = 0, layer = 70)
    Xt = CrossSection()
    Xt.add(width = elec_s, offset = 0, layer = 70)
    Xb = CrossSection()
    Xb.add(width = elec_s, offset = 0, layer = 70)
        
    L = M.extrude(X) #Left Trace
    Lt = Mt.extrude(Xt) #Left Trace
    Lb = Mb.extrude(Xb) #Left Trace 
    
    D << L
    D << Lt
    D << Lb
    return D

def connection_UR(x1,y1,x2,y2,elec_m,elec_s,e_e_gap,Rt): #right down
    
    D = Device()
    
    x1t = x1+elec_m/2+elec_s/2+e_e_gap
    x1b = x1-elec_m/2-elec_s/2-e_e_gap
    
    y2t = y2-elec_m/2-elec_s/2-e_e_gap
    y2b = y2+elec_m/2+elec_s/2+e_e_gap

    points = np.array([(x1,y1), (x1,y2), (x2,y2)])  
    points_t = np.array([(x1t,y1), (x1t,y2t), (x2,y2t)])  
    points_b = np.array([(x1b,y1), (x1b,y2b), (x2,y2b)])  
    
    M = pp.smooth(
        points = points,
        radius = Rt+elec_m/2+elec_s/2+e_e_gap,
        corner_fun = pp.arc,
        )
    M.rotate(90, center=(x1,y1))
    
    Mt = pp.smooth(
        points = points_t,
        radius = Rt,
        corner_fun = pp.arc,
        )
    Mt.rotate(90, center=(x1t,y1))
    
    Mb = pp.smooth(
        points = points_b,
        radius = Rt+2*(elec_m/2+elec_s/2+e_e_gap),
        corner_fun = pp.arc,
        )  
    Mb.rotate(90, center=(x1b,y1))
    
    X = CrossSection()
    X.add(width = elec_m, offset = 0, layer = 70)
    Xt = CrossSection()
    Xt.add(width = elec_s, offset = 0, layer = 70)
    Xb = CrossSection()
    Xb.add(width = elec_s, offset = 0, layer = 70)
        
    L = M.extrude(X) #Left Trace
    Lt = Mt.extrude(Xt) #Left Trace
    Lb = Mb.extrude(Xb) #Left Trace 
    
    D << L
    D << Lt
    D << Lb
    return D

def rotate90(c):
    num = len(c)

    for x in range(num):
        a = c[x][0]
        b = c[x][1]
        c[x][0] = b
        c[x][1] = -a
    return c

def via_test(x_pos, l_testpad, h_testpad, via, chip_width, chip_height):
    offset = 10
    D = Device('via test')
    D << pg.rectangle(size=(l_testpad,h_testpad), layer=10).move([x_pos - l_testpad/2,chip_height/2-h_testpad/2])
    D << pg.rectangle(size=(via,via), layer=2).move([x_pos - l_testpad/2,chip_height/2-via/2])
    D << pg.rectangle(size=(via,via), layer=2).move([x_pos + l_testpad/2 - via,chip_height/2-via/2])
    D << pg.rectangle(size=(l_testpad,h_testpad), layer=3).move([x_pos - l_testpad/2+via-l_testpad + offset,chip_height/2-h_testpad/2])
    D << pg.rectangle(size=(l_testpad,h_testpad), layer=3).move([x_pos + l_testpad/2-via - offset,chip_height/2-h_testpad/2])
    return D

def mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi):
    mm = 10**3
    um = 1 

    # Create CrossSections
    X1 = CrossSection()
    X2 = CrossSection()
    X1.add(width = W, offset = 0, layer = 30, name = 'wg')
    X2.add(width = W_tp, offset = 0, layer = 30, name = 'wg')
    
    # create Devices by extruding them
    P1 = pp.straight(length = 10*um)
    P2 = pp.straight(length = 10*um)
    WG1 = P1.extrude(X1)
    WG2 = P2.extrude(X2)
    
    # Place both cross-section Devices and quickplot them
    D = Device()
    wg1 = D << WG1
    wg2 = D << WG2
    wg2.movex(L_tp)
    
    # Create the transitional CrossSection
    Xtrans = pp.transition(cross_section1 = X1, cross_section2 = X2, width_type = 'linear')
    # Create a Path for the transitional CrossSection to follow
    P3 = pp.straight(length = L_tp)
    # Use the transitional CrossSection to create a Device
    WG_in = P3.extrude(Xtrans)
    WG_out1 = P3.extrude(Xtrans)
    WG_out2 = P3.extrude(Xtrans)
    WG_out1.mirror((0,1),(0,0))
    WG_out2.mirror((0,1),(0,0))
    
    WG_in << pg.rectangle(size=(L_mmi,W_mmi), layer=30).move([L_tp,-W_mmi/2])
    WG_in << WG_out1.move([L_mmi+2*L_tp,Y_mmi/2])
    WG_in << WG_out2.move([L_mmi+2*L_tp,-Y_mmi/2])
    return WG_in

def mzi(length, radius, angle, wg_width, Y_mmi):
    P1 = Path()        
    P1.append( pp.euler(radius = radius, angle = -angle) )
    P1.append( pp.euler(radius = radius, angle = angle) )
    P1.append( pp.straight(length = length) )
    P1.append( pp.euler(radius = radius, angle = angle) )
    P1.append( pp.euler(radius = radius, angle = -angle) )
    
    X = CrossSection()
    X.add(width = wg_width, offset = 0, layer = 30)
    waveguide_device1 = P1.extrude(X)
        
    E = Device('EOM_GHz')
    b1 = E.add_ref(waveguide_device1).move([0,-Y_mmi/2])
    b2 = E.add_ref(waveguide_device1).move([0,-Y_mmi/2])
    b2.mirror((0,0),(1,0))
    return E

def eom(wg_width, off_chip, W, L_tp, W_tp, L_mmi, W_mmi,Y_mmi,
        length, radius, x_pos, y_pos, middle_e_width, e_e_gap):
    
    if e_e_gap == 9:
        angle = 12.814353309
    elif e_e_gap == 7:
        angle = 12.1500390158
    elif e_e_gap == 11:
        angle = 13.4465651249      
    
    
    
    # Parameters
    mmi_length = L_tp*2+L_mmi
    side_electrode_width = middle_e_width*2
    
    eulerX = mod_euler(radius = radius, angle = angle)[1][0]
    racetrack_length = eulerX*4 + length
    #mzi_length = racetrack_length + mmi_length*2
    side =x_pos
    #side = (chip_width - mzi_length)/2
    
    
    # Devices
    M = mzi(length, radius, angle, wg_width, Y_mmi)
    
    mmiL = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR.mirror().move([mmi_length,0])
    
    E = Device('EOM')
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([-off_chip,y_pos-wg_width/2])
    E << mmiL.move([side,y_pos])
    E << M.move([side+mmi_length,y_pos])
    E << mmiR.move([side+mmi_length+racetrack_length,y_pos])
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([side+mzi_length,y_pos-wg_width/2])
    
    
    square = middle_e_width*0.9
    side_height = side_electrode_width*0.9
    square_rec_offset = (side_electrode_width - side_height)/2
    e_left = side+mmi_length+2*eulerX 
    e_right = e_left + length - square
    
    #side_e_width
    R = pg.rectangle(size=(length,middle_e_width), layer=40)
    R2 = pg.rectangle(size=(length,side_electrode_width), layer=40)
    S = pg.rectangle(size=(square,square), layer=50)
    S2 = pg.rectangle(size=(square,side_height), layer=50)
    
    #top electrode
    h_top = middle_e_width/2 + e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_top])
    E.add_ref(S2).move([e_left,h_top + square_rec_offset])
    E.add_ref(S2).move([e_right,h_top + square_rec_offset])
    
    #middle electrode
    E.add_ref(R).move([e_left,y_pos-middle_e_width/2])
    E.add_ref(S).move([e_left,y_pos-square/2])
    E.add_ref(S).move([e_right,y_pos-square/2])
    
    
    #bottom electrode
    h_bot = -middle_e_width/2 - side_electrode_width - e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_bot])
    E.add_ref(S2).move([e_left,h_bot + square_rec_offset])
    E.add_ref(S2).move([e_right,h_bot + square_rec_offset])
    return E

def eom23(wg_width, off_chip, W, L_tp, W_tp, L_mmi, W_mmi,Y_mmi,
        length, radius, x_pos, y_pos, middle_e_width, e_e_gap):
    
    if e_e_gap == 9:
        angle1 = 12.5196846104787
    elif e_e_gap == 7:
        angle1 = 11.83919343835311
    elif e_e_gap == 11:
        angle1 = 13.165741242693    
    
    
    
    # Parameters
    mmi_length = L_tp*2+L_mmi
    side_electrode_width = middle_e_width*2
    
    eulerX = mod_euler(radius = radius, angle = angle1)[1][0]
    racetrack_length = eulerX*4 + length
    #mzi_length = racetrack_length + mmi_length*2
    side =x_pos
    #side = (chip_width - mzi_length)/2
    
    
    # Devices
    M = mzi(length, radius, angle, wg_width, Y_mmi)
    
    mmiL = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR.mirror().move([mmi_length,0])
    
    E = Device('EOM')
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([-off_chip,y_pos-wg_width/2])
    E << mmiL.move([side,y_pos])
    E << M.move([side+mmi_length,y_pos])
    E << mmiR.move([side+mmi_length+racetrack_length,y_pos])
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([side+mzi_length,y_pos-wg_width/2])
    
    
    square = middle_e_width*0.9
    side_height = side_electrode_width*0.9
    square_rec_offset = (side_electrode_width - side_height)/2
    e_left = side+mmi_length+2*eulerX 
    e_right = e_left + length - square
    
    #side_e_width
    R = pg.rectangle(size=(length,middle_e_width), layer=40)
    R2 = pg.rectangle(size=(length,side_electrode_width), layer=40)
    S = pg.rectangle(size=(square,square), layer=50)
    S2 = pg.rectangle(size=(square,side_height), layer=50)
    
    #top electrode
    h_top = middle_e_width/2 + e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_top])
    E.add_ref(S2).move([e_left,h_top + square_rec_offset])
    E.add_ref(S2).move([e_right,h_top + square_rec_offset])
    
    #middle electrode
    E.add_ref(R).move([e_left,y_pos-middle_e_width/2])
    E.add_ref(S).move([e_left,y_pos-square/2])
    E.add_ref(S).move([e_right,y_pos-square/2])
    
    
    #bottom electrode
    h_bot = -middle_e_width/2 - side_electrode_width - e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_bot])
    E.add_ref(S2).move([e_left,h_bot + square_rec_offset])
    E.add_ref(S2).move([e_right,h_bot + square_rec_offset])
    return E

def rfim(wg_width, off_chip, W, L_tp, W_tp, L_mmi, W_mmi,Y_mmi,
        length, radius, x_pos, y_pos, middle_e_width, e_e_gap):
    
    if e_e_gap == 9:
        angle = 12.5196846104787
    elif e_e_gap == 7:
        angle = 11.83919343835311
    elif e_e_gap == 11:
        angle = 13.165741242693       
    
    
    
    # Parameters
    mmi_length = L_tp*2+L_mmi
    side_electrode_width = middle_e_width*2
    
    eulerX = mod_euler(radius = radius, angle = angle)[1][0]
    racetrack_length = eulerX*4 + length
    #mzi_length = racetrack_length + mmi_length*2
    side =x_pos
    #side = (chip_width - mzi_length)/2
    
    
    # Devices
    M = mzi(length, radius, angle, wg_width, Y_mmi)
    
    mmiL = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR.mirror().move([mmi_length,0])
    
    E = Device('EOM')
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([-off_chip,y_pos-wg_width/2])
    E << mmiL.move([side,y_pos])
    E << M.move([side+mmi_length,y_pos])
    E << mmiR.move([side+mmi_length+racetrack_length,y_pos])
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([side+mzi_length,y_pos-wg_width/2])
    
    
    square = middle_e_width*0.9
    side_height = side_electrode_width*0.9
    square_rec_offset = (side_electrode_width - side_height)/2
    e_left = side+mmi_length+2*eulerX 
    e_right = e_left + length - square
    
    #side_e_width
    R = pg.rectangle(size=(length,middle_e_width), layer=40)
    R2 = pg.rectangle(size=(length,side_electrode_width), layer=40)
    S = pg.rectangle(size=(square,square), layer=50)
    S2 = pg.rectangle(size=(square,side_height), layer=50)
    
    #top electrode
    h_top = middle_e_width/2 + e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_top])
    E.add_ref(S2).move([e_left,h_top + square_rec_offset])
    E.add_ref(S2).move([e_right,h_top + square_rec_offset])
    
    #middle electrode
    E.add_ref(R).move([e_left,y_pos-middle_e_width/2])
    E.add_ref(S).move([e_left,y_pos-square/2])
    E.add_ref(S).move([e_right,y_pos-square/2])
    
    
    #bottom electrode
    h_bot = -middle_e_width/2 - side_electrode_width - e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_bot])
    E.add_ref(S2).move([e_left,h_bot + square_rec_offset])
    E.add_ref(S2).move([e_right,h_bot + square_rec_offset])
    return E, e_left

def dcim(im_gap, im_length, coupler_l, im_r, im_angle,elec_w,e_e_gap,via,wg_width,V_Groove_Spacing):        
    P = Path()
    euler_y = mod_euler(radius = im_r, angle = im_angle)[1][1]
    euler_x = mod_euler(radius = im_r, angle = im_angle)[1][0]
    l_bend = ((V_Groove_Spacing - im_gap - 4*euler_y-wg_width)/2)/np.sin(np.pi*im_angle/180 ) 
    P.append( pp.euler(radius = im_r, angle = -im_angle) )
    P.append( pp.straight(length = l_bend) )  
    P.append( pp.euler(radius = im_r, angle = im_angle) )
    P.append( pp.straight(length = coupler_l) )  
    P.append( pp.euler(radius = im_r, angle = im_angle) )
    P.append( pp.euler(radius = im_r, angle = -im_angle) )
    P.append( pp.straight(length = im_length) )  
    P.append( pp.euler(radius = im_r, angle = -im_angle) )
    P.append( pp.euler(radius = im_r, angle = im_angle) )
    P.append( pp.straight(length = coupler_l) )  
    P.append( pp.euler(radius = im_r, angle = im_angle) )
    P.append( pp.straight(length = l_bend) )  
    P.append( pp.euler(radius = im_r, angle = -im_angle) )
    
    P.movey(V_Groove_Spacing)
    X = CrossSection()
    X.add(width = wg_width, offset = 0, layer = 30)
    
    IM = Device('IM')
    IM<< P.extrude(X)
    IM << P.extrude(X).mirror(p1 = [1,V_Groove_Spacing/2], p2 = [2,V_Groove_Spacing/2])
    R1 = pg.rectangle(size = (im_length, elec_w), layer = 40); 
    R2 = pg.rectangle(size = (im_length, elec_w), layer = 40); 
    R3 = pg.rectangle(size = (im_length, elec_w), layer = 40); 
    R4 = pg.rectangle(size = (im_length, elec_w), layer = 40); 

    movex = euler_x*4+coupler_l+l_bend*np.cos(np.pi*im_angle/180 )
    movey = euler_y*2+im_gap/2+wg_width
    IM << R1.move([movex,V_Groove_Spacing/2+movey+e_e_gap/2-wg_width/2])
    IM << R2.move([movex,V_Groove_Spacing/2+movey-e_e_gap/2-elec_w-wg_width/2])
    IM << R3.move([movex,V_Groove_Spacing/2-movey+e_e_gap/2+wg_width/2])
    IM << R4.move([movex,V_Groove_Spacing/2-movey-e_e_gap/2-elec_w+wg_width/2])
    return IM, movex

def dcpm(L,elec_w,e_e_gap,via,wg_width):        
    P = Path()
    P.append( pp.straight(length = L) )  
    
    X = CrossSection()
    X.add(width = wg_width, offset = 0, layer = 30)
    DCPM = Device()
    DCPM << P.extrude(X)
    R1 = pg.rectangle(size = (L, elec_w), layer = 40); 
    R2 = pg.rectangle(size = (L, elec_w), layer = 40); 
    DCPM << R1.move([0,e_e_gap/2])
    DCPM << R2.move([0,-elec_w-e_e_gap/2])
    return DCPM

def rfpm(wg_width, length,middle_e_width, e_e_gap):
    
    side_electrode_width = middle_e_width*2
    
    P = Path()
    P.append( pp.straight(length = length) )  
    
    X = CrossSection()
    X.add(width = wg_width, offset = 0, layer = 30)
    RFPM = Device()
    RFPM << P.extrude(X)
    Rt = pg.rectangle(size = (length, side_electrode_width), layer = 40); 
    Rm = pg.rectangle(size = (length, middle_e_width), layer = 40); 
    Rb = pg.rectangle(size = (length, side_electrode_width), layer = 40); 
    RFPM << Rt.move([0,e_e_gap/2])
    RFPM << Rm.move([0,-middle_e_width-e_e_gap/2])
    RFPM << Rb.move([0,-middle_e_width-side_electrode_width-e_e_gap-e_e_gap/2])
    
   
    square = middle_e_width*0.9
    side_height = side_electrode_width*0.9
    square_rec_offset = (side_electrode_width - side_height)/2
    square_rec_offset_m = (middle_e_width - square)/2
    e_left = 0
    e_right = e_left + length - square
    
    #side_e_width
    R = pg.rectangle(size=(length,middle_e_width), layer=40)
    R2 = pg.rectangle(size=(length,side_electrode_width), layer=40)
    S = pg.rectangle(size=(square,square), layer=50)
    S2 = pg.rectangle(size=(square,side_height), layer=50)
    
    #top electrode
    h_top = e_e_gap/2
    RFPM.add_ref(S2).move([e_left,h_top + square_rec_offset])
    RFPM.add_ref(S2).move([e_right,h_top + square_rec_offset])
    
    #middle electrode
    h_mid = -middle_e_width-e_e_gap/2
    RFPM.add_ref(S).move([e_left,h_mid + square_rec_offset_m])
    RFPM.add_ref(S).move([e_right,h_mid + square_rec_offset_m])
    
    
    #bottom electrode
    h_bot = -middle_e_width-side_electrode_width-e_e_gap-e_e_gap/2
    RFPM.add_ref(S2).move([e_left,h_bot + square_rec_offset])
    RFPM.add_ref(S2).move([e_right,h_bot + square_rec_offset])
    
    return RFPM

def dcimthin(wg_width, off_chip, W, L_tp, W_tp, L_mmi, W_mmi,Y_mmi,
        length, radius, x_pos, y_pos, middle_e_width, e_e_gap):
    
    if e_e_gap == 9:
        angle = 12.5196846104787
    elif e_e_gap == 7:
        angle = 11.83919343835311
    elif e_e_gap == 11:
        angle = 13.165741242693        
    
    
    
    # Parameters
    mmi_length = L_tp*2+L_mmi
    side_electrode_width = middle_e_width*2
    
    eulerX = mod_euler(radius = radius, angle = angle)[1][0]
    racetrack_length = eulerX*4 + length
    #mzi_length = racetrack_length + mmi_length*2
    side =x_pos
    #side = (chip_width - mzi_length)/2
    
    
    # Devices
    M = mzi(length, radius, angle, wg_width, Y_mmi)
    
    mmiL = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR = mmi(W, L_tp, W_tp, L_mmi, W_mmi, Y_mmi)
    mmiR.mirror().move([mmi_length,0])
    
    E = Device('EOM')
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([-off_chip,y_pos-wg_width/2])
    E << mmiL.move([side,y_pos])
    E << M.move([side+mmi_length,y_pos])
    E << mmiR.move([side+mmi_length+racetrack_length,y_pos])
    #E << pg.rectangle(size=(side+off_chip,wg_width), layer=1).move([side+mzi_length,y_pos-wg_width/2])
    
    e_left = side+mmi_length+2*eulerX 
    
    #side_e_width
    R = pg.rectangle(size=(length,middle_e_width), layer=40)
    R2 = pg.rectangle(size=(length,side_electrode_width), layer=40)
    
    #top electrode
    h_top = middle_e_width/2 + e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_top])
    
    #middle electrode
    E.add_ref(R).move([e_left,y_pos-middle_e_width/2])
    
    
    #bottom electrode
    h_bot = -middle_e_width/2 - side_electrode_width - e_e_gap + y_pos
    E.add_ref(R2).move([e_left,h_bot])
    return E, e_left

def fang(wg_width,length,orientation):
    F = Device()
    w1 = wg_width
    X1 = CrossSection()
    X1.add(width = w1, offset = 0, layer = 30, ports = ('in','out'))
    
    P = Path()
    P.append( pp.euler(radius = 50, angle = 45) ) # Euler bend (aka "racetrack" curve)
    fang = P.extrude(X1)
    fang = F.add_ref(fang)
    
        
    D = pg.taper(length = length, width1 = w1, width2 = 0.000001, port = None, layer = 30)
    taper = F.add_ref(D)
    taper.connect(port=1, destination=fang.ports['out'])
    
    #Defualt is RU, right up
    if orientation == 'RD':
        F.mirror(p1 = [0,0], p2 = [1,0])
    elif orientation == 'LU':
        F.mirror(p1 = [0,0], p2 = [0,1])
    elif orientation == 'LD':
        F.rotate(180, center = [0,0])     
    
    
    return F

def find_ey_d(target,dec,prev,radius):
    for n in range(1,10):
        euler_y=mod_euler(radius = radius, angle = prev+dec*n)[1][1]
        if n == 1 and euler_y > target:
            d = 0
            break
        elif euler_y > target:
            d = n-1
            break   
        else:
            d = 9
    return d

def find_ey(target,radius):
    ds = 10
    prev = 0
    for n in range(-1,20):
        dn = ds*10**(-n)
        ey = dn*find_ey_d(target,dn,prev,radius)
        prev = prev+ey       
    return prev