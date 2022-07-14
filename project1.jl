using JuMP
using DelimitedFiles
using Gurobi

I = 6; #customers(regions)
J = 10; #DC / customer locations
T = 5 #5 years


"fixed costs of potential warehouses: small and large"
f = [300000 250000 220000 220000 240000 500000 420000 375000 375000 400000]; #1x10

"Shipping costs, four units"
c = [2 2.5 3.5 4 5 5.5
    2.5	2.5	2.5	3 4 4.5
    3.5	3.5	2.5	2.5	3 3.5
    4 4	3 2.5 3 2.5
    4.5	5 3	3.5	2.5 4
    2 2.5 3.5 4 5 5.5
    2.5	2.5	2.5	3 4 4.5
    3.5	3.5	2.5	2.5	3 3.5
    4 4	3 2.5 3 2.5
    4.5	5 3	3.5	2.5 4]; #10x6
c=transpose(c)
"Converting shipping cost to 1 unit. Substract 3 dollars for flat fee"
c = (c-(ones(I,J)*3))/4
#c=c/4

"demand for each customer for 5 years"
d = [320000	576000	1036800	1866240	1866240
    200000	360000	648000 1166400	1166400
    160000	288000	518400	933120	933120
    220000	396000	712800	1283040	1283040
    350000	630000	1134000	2041200	2041200
    175000	315000	567000	1020600	1020600];
#d=transpose(d)

"Vector of capacity for warehouses, small and large"
capacity_small = 2000000
capacity_large = 4000000

#------
# MODEL
#------

model = Model(Gurobi.Optimizer);

@variable(model, x[1:J, 1:T] >= 0, Bin); #0/1 DC j is open for time period t
@variable(model, y[1:I, 1:J, 1:T] >= 0, Int); #units of products shipped from DC j to customer i in time period t.
@variable(model, z[1:J, 1:T] >= 0, Bin); #helping the lease constraint

@objective(model, Min,
    sum(f[j]*x[j,t] for j=1:J, t = 1:T) #minimer fixed costs for alle DC for over alle år!
    + sum(0.2 * y[i,j,t] for i=1:I, j=1:J, t=1:T) #minimer varible cost for all products shipped from DC j to customer i in time period t
    + sum(sum(c[i,j]*y[i,j,t] for t = 1:T) for j=1:J, i=1:I) #minimer shipment costs for alle produkter for alle år "CHECK THIS"
    + sum(475000 * x[j,t] + sum(0.165 * y[i,j,t] for i=1:I) for j=1:J, t=1:T)); #minimer inventory cost for alle j DC for alle år
    #+ sum(0.165 * y[i,j,t] for j=1:J, i=1:I, t=1:T)); #minimer inventory cost for alle j DC for alle år

#sum of flow of units from all DC j to customer i is equal to demand for customer i to custumer t for all years"
@constraint(model,[i = 1:I, t=1:T], sum(y[i,j,t] for j = 1:J) == d[i,t]);

@constraint(model,[i = 1:I, t=1:T], sum(y[i,j,t] for j = 1:J) <= sum(x[j,t]*d[i,t] for j = 1:J));

#@constraint(model,[j = 1:J, t=1:T, i=1:I], y[i,j,t] <= x[j,t]*capacity_large);

#Constraint for capacity for small DC"
@constraint(model,[j = 1:5, t=1:T], sum(y[i,j,t] for i=1:I) <= capacity_small*x[j,t]);

#Constraint for capacity for large DC"
@constraint(model,[j = 6:10, t=1:T], sum(y[i,j,t] for i=1:I) <= capacity_large*x[j,t]);

#Constraint for only 1 DC pr customer (region)"
@constraint(model,[j=1:5, t=1:T], x[j,t] + x[j+5,t] <= 1);

#Constraint for DC has to be open at least 3 years once opened" skal kunne lukke igen
@constraint(model, [j=1:J, t=1:(T-2)], x[j,t]+x[j,t+1]+x[j,t+2] >= 3*z[j,t]);
@constraint(model, [j=1:J, t=1:(T-1)], x[j,t]+x[j,t+1] >= 2*z[j,t]);

@constraint(model, [j=1:J, t=1:T], x[j,t]-z[j,t] <= (t>1 ? x[j,t-1] : 0));
@constraint(model, [j=1:J, t=1:T], sum(z[j,t] for t in 1:T) <= 2);
@constraint(model, [j=1:J, t=1:T], z[j,t] <= x[j,t]);

#-------
# SOLVE
#-------
optimize!(model)
println();
for j = 1:J
    for i = 1:I
        for t = 1:T
            if (value(y[i,j,t]) > 0)
                println("Facility,", j, " ,serves region,", i, ",at year,", t, ",with flow,", value(y[i,j,t]))
            end
        end
    end
end
println(objective_value(model))
