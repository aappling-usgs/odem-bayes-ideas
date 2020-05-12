data {
  // Parameters of priors
  real<lower=0> NEP_mu_min;
  real<lower=0> NEP_mu_max;
  real<lower=0> NEP_sigma;
  real<lower=0> SED1_mu_min;
  real<lower=0> SED1_mu_max;
  real<lower=0> SED1_sigma;
  real<lower=0> MIN_mu_min;
  real<lower=0> MIN_mu_max;
  real<lower=0> MIN_sigma;
  real<lower=0> SED2_mu_min;
  real<lower=0> SED2_mu_max;
  real<lower=0> SED2_sigma;

  // Error distributions
  real<lower=0> err_sigma;

  // Data dimensions
  int<lower=1> d; // number of dates
  int N_obs; // number of dates with observations
  int<lower=1, upper=d> ii_obs[N_obs];

  // Data
  real DO_epi_init; // need a starting point. this is one option.
  real DO_hyp_init;
  real khalf;
  real theta1[d];
  real theta2[d];
  real volume_epi[d];
  real area_epi[d];
  real volume_hyp[d];
  real area_hyp[d];
  real k600[d];
  real o2sat[d];
  real tddepth[d];
  real DO_obs_epi[N_obs]; // how do we accept missing data? https://mc-stan.org/docs/2_23/stan-users-guide/sliced-missing-data.html
  real DO_obs_hyp[N_obs];
}
parameters {
  real<lower=0> NEP_mu;
  real<lower=0, upper = 100> NEP[d];
  real<lower=0> SED1_mu;
  real<lower=0, upper=3200> SED1[d];
  real<lower=0> MIN_mu;
  real<lower=0, upper=1000> MIN[d];
  real<lower=0> SED2_mu;
  real<lower=0, upper=1000> SED2[d];
}
transformed parameters {
  real DO_epi[d];
  real dDOdt_epi[d];
  real DO_hyp[d];
  real dDOdt_hyp[d];
  real flux_epi[d];
  real flux_hyp[d];
  real delvol_epi[d];
  real delvol_hyp[d];
  real x_do1[d];
  real x_do2[d];

  DO_epi[1] = DO_epi_init;
  DO_hyp[1] = DO_hyp_init;
  dDOdt_epi[1] = 0;
  dDOdt_hyp[1] = 0;
  flux_epi[1] = 0;
  flux_hyp[1] = 0;
  x_do1[1] = 0; // new
  x_do2[1] = 0; // new
  delvol_epi[1] = 0; // new
  delvol_hyp[1] = 0; // new

  for(i in 2:d) {

    delvol_epi[i] = (volume_epi[i] -  volume_epi[i-1])/volume_epi[i-1];
    if (delvol_epi[i] >= 0){
      x_do1[i] = DO_hyp[i-1];
    } else {
      x_do1[i] = DO_epi[i-1];
    }

    delvol_hyp[i] = (volume_hyp[i] -  volume_hyp[i-1])/volume_hyp[i-1];
    if (delvol_hyp[i] >= 0){
      x_do2[i] = DO_epi[i-1];
    } else {
      x_do2[i] = DO_hyp[i-1];
    }

    // FluxAtm multiplied by 0.1 to help fits
    dDOdt_epi[i] = NEP[i-1] * (DO_epi[i-1]/(khalf + DO_epi[i-1])) * theta1[i] -
    SED1[i-1] *  (DO_epi[i-1]/(khalf + DO_epi[i-1])) * theta1[i] * area_epi[i-1]/volume_epi[i-1] +
    k600[i-1] * 0.1 * (o2sat[d-1] - DO_epi[i-1])/tddepth[i-1] +
    delvol_epi[i] * x_do1[i]; // New was i-1

    if(abs(dDOdt_epi[i])>abs(DO_epi[i-1])){
      if(dDOdt_epi[i] < 0){
        flux_epi[i] = - DO_epi[i-1];
      }else{
         flux_epi[i] = dDOdt_epi[i];
      }
    }else{
      flux_epi[i] = dDOdt_epi[i];
    }

    DO_epi[i] =  (DO_epi[i-1] + flux_epi[i]) * volume_epi[i-1]/volume_epi[i];

    dDOdt_hyp[i] =  - MIN[i-1] * (DO_hyp[i-1]/(khalf + DO_hyp[i-1])) * theta2[i] -
    SED2[i-1] *  (DO_hyp[i-1]/(khalf + DO_hyp[i-1])) * theta2[i] * area_hyp[i-1]/volume_hyp[i-1] +
    delvol_hyp[i] * x_do2[i]; // New, was i-1

    if(abs(dDOdt_hyp[i])>abs(DO_hyp[i-1])){
      if(dDOdt_hyp[i] < 0){
        flux_hyp[i] = - DO_hyp[i-1];
      }else{
         flux_hyp[i] = dDOdt_hyp[i];
      }
    }else{
      flux_hyp[i] = dDOdt_hyp[i];
    }

    DO_hyp[i] =  (DO_hyp[i-1] + flux_hyp[i])* volume_hyp[i-1]/volume_hyp[i];

  }
}
model {
  // Variables declared in the model block cannot be used elsewhere
  // NEP_mu ~  uniform(0,1);// uniform(NEP_mu_min, NEP_mu_max);
  // NEP ~ normal(0.5, 0.01);//normal(NEP_mu, NEP_sigma);
  // SED1_mu ~ uniform(SED1_mu_min, SED1_mu_max);
  // SED1 ~ normal(100, 1);
  // MIN_mu ~ uniform(MIN_mu_min, MIN_mu_max);
  // MIN ~ normal(2000, 1);
  // SED2_mu ~ uniform(SED2_mu_min, SED2_mu_max);
  // SED2 ~ normal(1000, 1);

  for(i in 2:d) {
    NEP[i] ~ normal(NEP[i-1],1);
    MIN[i] ~ normal(MIN[i-1],10);
    SED1[i] ~ normal(SED1[i-1],10);
    SED2[i] ~ normal(SED2[i-1],10);
  }

  for(i in 1:N_obs) {
   NEP[ii_obs[i]] ~ normal(10,1);
   MIN[ii_obs[i]] ~ normal(3000,100);
   SED1[ii_obs[i]] ~ normal(5000,100);
   SED2[ii_obs[i]] ~ normal(3000,100);
   DO_obs_epi[i] ~ normal(DO_epi[ii_obs[i]], 10); // error in "i", sigma of 1 way too low
   DO_obs_hyp[i] ~ normal(DO_hyp[ii_obs[i]], 10); // error in "i", sigma of 1 way too low
  }

}
generated quantities {
  real Fnep[d];
  real Fsed1[d];
  real Fatm[d];
  real Fmin[d];
  real Fsed2[d];
  real Ftotepi[d];
  real Ftotepi2[d];
  Ftotepi2[1] = DO_epi_init;
  Ftotepi[1] = 0;
  Fnep[1] = 0;
  Fsed1[1] = 0;
  Fatm[1] = 0;
  Fmin[1] = 0;
  Fsed2[1] = 0;
  for (i in 2:d){
    Ftotepi2[i] = (DO_epi[i-1] + flux_epi[i]) * volume_epi[i-1]/volume_epi[i];
    Ftotepi[i] = NEP[i-1] * (DO_epi[i-1]/(khalf + DO_epi[i-1])) * theta1[i] -
    SED1[i-1] *  (DO_epi[i-1]/(khalf + DO_epi[i-1])) * theta1[i] * area_epi[i-1]/volume_epi[i-1] +
    k600[i-1] * (o2sat[d-1] - DO_epi[i-1])/tddepth[i-1];
    Fnep[i] = NEP[i-1] * (DO_epi[i-1]/(khalf + DO_epi[i-1])) * theta1[i];
    Fsed1[i] = -SED1[i-1] *  (DO_epi[i-1]/(khalf + DO_epi[i-1])) * theta1[i] * area_epi[i-1]/volume_epi[i-1];
    Fatm[i] = k600[i-1] * (o2sat[d-1] - DO_epi[i-1])/tddepth[i-1];
    Fmin[i] =  - MIN[i-1] * (DO_hyp[i-1]/(khalf + DO_hyp[i-1])) * theta2[i];
    Fsed2[i] = -SED2[i-1] *  (DO_hyp[i-1]/(khalf + DO_hyp[i-1])) * theta2[i] * area_hyp[i-1]/volume_hyp[i-1];
  }

}
