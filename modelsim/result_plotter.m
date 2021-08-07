
clear; close all; clc;

t = readtable("nl_test_results.csv");
t2 = readtable("mac_mul_test_results.csv");
t3 = readtable("mac_add_test_results.csv");


fmac = @(v1, v2) cos(pi.*0.5.*(v1/7)) * cos(pi.*0.5.*(v2/7));
fmac_add = @(v1, v2) cos(pi.*0.5.*(v1/7)) + cos(pi.*0.5.*(v2/7));

V_b = t2{:,1};
V_c = t2{:,2};
I_out_I_m = t2{:,3};

I_out_I_m_t = [];
for i = 1:max(size(V_b))
    I_out_I_m_t = [I_out_I_m_t, fmac(V_b(i), V_c(i))];
end

%Get the surface for the MAC results
tri = delaunay(V_b, V_c);


V_a_a = t3{:,1};
V_b_a = t3{:,2};
I_out_add = t3{:,3};
I_out_add_t = [];
for i = 1:max(size(V_a_a))
    I_out_add_t = [I_out_add_t, fmac_add(V_a_a(i), V_b_a(i))];
end

tri2 = delaunay(V_a_a, V_b_a);

v_alpha = t{:,1};
I_out_I = t{:,2};
I_out_Q = t{:,3};

f_nl = @(v) cos(v).*sech(cos(v));

figure();
title("NL Output Verification");
subplot(1,2,1);
hold on
plot(v_alpha, I_out_I, "linewidth", 2);
plot(v_alpha, I_out_Q, "linewidth", 2);
xlabel("V_{\alpha}");
ylabel("I_{out}");
legend("I", "Q");
title("NL Chip Output");

subplot(1,2,2);
fplot(f_nl, [-2*pi, 2*pi]);
title("cos(x)*sech(cos(x))");
xlabel("x");
ylabel("f(x)");


figure();
subplot(1,2,1);
%scatter3(V_b, V_c, I_out_I_m);
h = trisurf(tri, V_b, V_c, I_out_I_m);
%axis off
l = light('Position',[-50 -15 29]);
%set(gca,'CameraPosition',[208 -50 7687])
lighting phong
shading interp
colorbar EastOutside
title("MAC mul data")
xlabel("V_B");
ylabel("V_C")

subplot(1,2,2);
%scatter3(V_b, V_c, I_out_I_m);
h = trisurf(tri, V_b, V_c, I_out_I_m_t);
%axis off
l = light('Position',[-50 -15 29]);
%set(gca,'CameraPosition',[208 -50 7687])
lighting phong
shading interp
colorbar EastOutside
title("cos(X)*cos(Y)");
xlabel("X");
ylabel("Y");




figure();
subplot(1,2,1);
%scatter3(V_b, V_c, I_out_I_m);
h = trisurf(tri2, V_a_a, V_b_a, I_out_add);
%axis off
l = light('Position',[-50 -15 29]);
%set(gca,'CameraPosition',[208 -50 7687])
lighting phong
shading interp
colorbar EastOutside
title("MAC add data")
xlabel("V_A");
ylabel("V_B");

subplot(1,2,2);
%scatter3(V_b, V_c, I_out_I_m);
h = trisurf(tri2, V_a_a, V_b_a, I_out_add_t);
%axis off
l = light('Position',[-50 -15 29]);
%set(gca,'CameraPosition',[208 -50 7687])
lighting phong
shading interp
colorbar EastOutside
title("cos(X)+cos(Y)");
xlabel("X");
ylabel("Y");

