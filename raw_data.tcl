################
### add data ###
################
#####check number of dcd files #####
mol new ionized.psf waitfor all
mol addfile ionized.pdb waitfor all
mol addfile ionized.smd.2.dcd waitfor all
mol addfile ionized.smd.3.dcd waitfor all
mol addfile ionized.smd.4.dcd waitfor all
mol addfile ionized.smd.5.dcd waitfor all
mol addfile ionized.smd.5.dcd waitfor all

##############
### Lenght ###
##############
#seleccionamos el carbono alfa de ALA1 y ALA10
set sel [atomselect top "residue 0 and name CA or residue 88 and name CA"]
#obtengo la posicion de ambas ALA segun x y z
$sel get {x y z}

#creo un archivo al cual ingresar los datos que me interesan
set output [open "length.dat" w]

#obtengo la cantidad de frames para hacer el análisis de posiciones de las ALA por cada uno de ellos
set n [molinfo top get numframes]

#hago un ciclo que valla desde 0 a 998
for { set i 0 } { $i < $n } { incr i } {
  $sel frame $i
  $sel update
 # $sel get {x y z}
  #puts $output $i
  puts $output [ $sel get {x y z} ]
  #set i [expr { $i+1 } ]
}
close $output

##############
### hbonds ###
##############
#hbonds plugin config
#https://www.ks.uiuc.edu/Research/vmd/plugins/hbonds/

hbonds -sel1 [atomselect top "chain A  and resid 2838 2839 2840"] -sel2 [atomselect top "chain A  and resid 2853 2854 2855 2856 2857 2858 2859"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_AB.dat
hbonds -sel1 [atomselect top "chain A  and resid 2853 2854 2855 2856 2857 2858 2859"] -sel2 [atomselect top "chain A  and resid 2889 2890 2891 2892 2893 2894"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_BE.dat
hbonds -sel1 [atomselect top "chain A  and resid 2889 2890 2891 2892 2893 2894"] -sel2 [atomselect top "chain A  and resid 2881 2882 2883 2884 2885 2886"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_ED.dat
hbonds -sel1 [atomselect top "chain A  and resid 2845 2846 2847"] -sel2 [atomselect top "chain A  and resid 2912 2913 2914 2915 2916 2917 2918 2919 2920"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_A2G.dat
hbonds -sel1 [atomselect top "chain A  and resid 2912 2913 2914 2915 2916 2917 2918 2919 2920"] -sel2 [atomselect top "chain A  and resid 2903 2904 2905 2906 2907 2908 2909"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_GF.dat
hbonds -sel1 [atomselect top "chain A  and resid 2903 2904 2905 2906 2907 2908 2909"] -sel2 [atomselect top "chain A  and resid 2867 2868 2869 2870"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_FC.dat
hbonds -sel1 [atomselect top "chain A  and resid 2867 2868 2869 2870"] -sel2 [atomselect top "chain A  and resid 2873 2874"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_beta_CC2.dat
##all hbonds##
hbonds -sel1 [atomselect top "protein"] -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_all.dat

#########################
### hbonds non-native ###
#########################
#hbonds plugin config
#https://www.ks.uiuc.edu/Research/vmd/plugins/hbonds/
###############################################
#### CHECK THAT CHAIN AND RESID ARE CORRECT ###
###############################################

hbonds -sel1 [atomselect top "chain I  and resid 2838 2839 2840"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_AB_all.dat
hbonds -sel1 [atomselect top "chain I  and resid 2853 2854 2855 2856 2857 2858 2859"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_BE_all.dat
hbonds -sel1 [atomselect top "chain I  and resid 2889 2890 2891 2892 2893 2894"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_ED_all.dat
hbonds -sel1 [atomselect top "chain I  and resid 2845 2846 2847"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_A2G_all.dat
hbonds -sel1 [atomselect top "chain I  and resid 2912 2913 2914 2915 2916 2917 2918 2919 2920"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_GF_all.dat
hbonds -sel1 [atomselect top "chain I  and resid 2903 2904 2905 2906 2907 2908 2909"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_FC_all.dat
hbonds -sel1 [atomselect top "chain I  and resid 2867 2868 2869 2870"] -sel2 $protein -dist 3.5 -ang 30 -writefile yes -plot no -outfile hbonds_CC2_all.dat

########################
### getting energies ###
########################
#NAMD enegy plugin
#https://www.ks.uiuc.edu/Research/vmd/plugins/namdenergy/

#path to namd executable #CHECK CORRECTNESS
set namd "C:/Users/pab_b/Documents/tesis/simulacion/NAMD/namd2.exe"

# set variables
set protein [atomselect top protein]
set water [atomselect top water]

#commands to run
namdenergy -vdw -elec -sel $protein -ofile protein_energy.dat -par par_all36_prot_lipid_water_ions.prm -exe $namd
namdenergy -vdw -elec -sel $protein $water -ofile protwater_energy.dat -par par_all36_prot_lipid_water_ions.prm -exe $namd
