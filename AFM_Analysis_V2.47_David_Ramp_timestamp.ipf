#pragma rtGlobals=1		// Use modern global access method.
#include <Readback ModifyStr>  //Contains a string utility function,  GetNumFromModifyStr( modstr, key, listChar, itemNo ), that helps with parsing the string returned by TraceInfo or AxisInfo.
//#include ":IFDL v4 Procedures:IFDL"
//#include ":IFDL Procedures:Apply Filter"

// This function underwent major changes.  The FX panel now includes the option of fitting several different polymer
// elasticity models to the data.  Here are the references for the models:
// WLC 							as old one
// WLC with Segment elasticity		Urry et al., Phil. Trans. R. Soc. Lond. B (2002) 357, 169-184
// FJC (with Segment elasticity)		Rief et al,. Science (1997) 275, 1295-1297
// FRC/EJC						Lidavaru et al., Macromolecules (2003) 36, 3732-3744
// TC							Minh Toan et al., Biophysical Journal (2005) 89, 80-96
// The values of the fitting parameters are saved in the matrix root:FX_Analysis:Fits:FitParam, the info of this 
// wave gives the order of the values (one column for each trace).
// The FC panel now includes the possibility to display the length based on the WLC and the experimental force
// trace.  If you place the A cursor on a step and hit the button "Unfolding" or "Refolding", you add an unfolding or 
// refolding event to the WLC prediction (hit "Display WLC" again).  These events are stored in the matrix
// root:FC_Analysis:Events.  In addition, new functions were added to detect steps in the length wave automatically. 


//*********************************for capturing input events**************************************//
static constant hook_mousemoved=4
static constant hook_mousedown=3
static constant hook_mouseup=5
static constant hook_keyboard=11
//***************************************************************************************************//


Menu "Macros"
	"-"
	"Analysis", whiplash()
	"Panel", AFMAnalysisPanel()
	"FX Import", FXImportWaves()
	"FC Import", FCImportWaves()
	"-"
	"Add Graph Info/F7",AddInfoStamp()
End

Macro whiplash()
	InitializeA()
	AFMAnalysisPanel()
End

Function InitializeA()
	// Initialize for FXA
	NewDataFolder/O/S root:Data
	NewDataFolder/O root:FX_Analysis
	NewDataFolder/O root:FX_Analysis:Fits
	NewDataFolder/O root:FX_Analysis:Fits:WLC
	NewDataFolder/O root:FX_Analysis:Fits:Variables
	NewDataFolder/O root:FX_Analysis:Persistence
	String/G root:FX_Analysis:LengthWaveName
	String/G root:FX_Analysis:ForceWaveName 
	Variable/G root:FX_Analysis:DisplayNumber=1
	Variable/G root:FX_Analysis:DisplayStartNumber=0
	Variable/G root:FX_Analysis:FXInfoFlag
	Variable/G root:FX_Analysis:FXDisplayUncorrected=0
	Variable/G root:FX_Analysis:PolymerElasticityModel=0
	Variable/G root:FX_Analysis:CorrectPolynomial=1
	Variable/G root:FX_Analysis:Fits:Variables:PersistenceLength=0.4
	Variable/G root:FX_Analysis:Fits:Variables:ContourLength=100
	Variable/G root:FX_Analysis:Fits:Variables:SegmentElasticity=10000
	Variable/G root:FX_Analysis:Fits:Variables:ContourLengthincrement=24
	Variable/G root:FX_Analysis:Fits:Variables:BondAngle=40
	Variable/G root:FX_Analysis:Fits:Variables:ChainThickness=0.25	//nm
	Variable/G root:FX_Analysis:Fits:Variables:DiscSeparation=0.38	//nm
	Variable/G root:FX_Analysis:Fits:Variables:c=1
	Variable/G root:FX_Analysis:Fits:Variables:NumberOfCurves=1
	Variable/G root:FX_Analysis:Fits:Tags=0
	Variable/G root:FX_Analysis:Fits:Separate=0
	Variable/G root:FX_Analysis:Fits:SetLtoCursor=1
	Variable/G root:FX_Analysis:nextwavenumber
	Variable/G root:FX_Analysis:Fits:Variables:chisq
	Variable/G root:FX_Analysis:PeakStartRef=0
	Variable/G root:FX_Analysis:PeakDetectorLevel=100
	Variable/G root:FX_Analysis:PeakDetectorSmooth=31
	Variable/G root:FX_Analysis:SpringConstant
	Variable/G root:FX_Analysis:ExcursionSize = 400
	Variable/G root:FX_Analysis:ExcursionRate = 0
	Variable/G root:FX_Analysis:Temperature = 23
	Variable/G root:FX_Analysis:HistDeltaNumEvents
	Variable/G root:FX_Analysis:HistForcesNumEvents
	Variable/G root:FX_Analysis:HistpNumEvents
	Variable/G root:FX_Analysis:HistLcNumEvents
	if ( ! WaveExists(root:FX_Analysis:RecordNumber))
		Make/T/N=200 root:FX_Analysis:RecordNumber
	endif
	if ( ! WaveExists(root:FX_Analysis:Fits:FitParam))
		Make/N=(1000,20,40) root:FX_Analysis:Fits:FitParam=-1
	endif
	
	// Initialize for FCA
	NewDataFolder/O root:FC_Analysis
	NewDataFolder/O root:FC_Analysis:Shift
	NewDataFolder/O root:FC_Analysis:Fits
	NewDataFolder/O root:FC_Analysis:Fits:WLC
	NewDataFolder/O root:FC_Analysis:Fits:ContourData
	NewDataFolder/O root:FC_Analysis:Fits:PersistenceData
	NewDataFolder/O root:FC_Analysis:Fits:xNormData
	NewDataFolder/O root:FC_Analysis:SumTraces
	NewDataFolder/O root:FC_Analysis:Steps
	
	Variable/G root:FC_Analysis:FCLevel   	//for measuring stepsizes easily
	Variable/G root:FC_Analysis:FCstepSize
	Variable/G root:FC_Analysis:FCstepForce
	Make/N=0 root:FC_Analysis:FCsteps
	Make/N=0 root:FC_Analysis:FCforces
	Make/N=0 root:FC_Analysis:FCstepsNo
	
	String/G root:FC_Analysis:ExpType="none"
	String/G root:FC_Analysis:ForceWaveName
	String/G root:FC_Analysis:LengthWaveName
//	String/G root:FC_Analysis:SumTraces:SourceFolder="root:Data"
	String/G root:FC_Analysis:SumTraces:DestinationFolder="root:FC_Analysis:SumTraces"
	String/G root:FC_Analysis:SumTraces:AvgTracePrefix = "cut_"
	Variable/G root:FC_Analysis:BootStrapNumIterations=500
	Variable/G root:FC_Analysis:BootStrapConstrain=0	//	0: unconstrained ; 1: constrained
	Variable/G root:FC_Analysis:FCDisplayNumber=1
	Variable/G root:FC_Analysis:FCDisplayStartNumber=0
	Variable/G root:FC_Analysis:FCInfoFlag
	Variable/G root:FC_Analysis:FCDisplayUncorrected=0
	Variable/G root:FC_Analysis:SpringConstant	
	Variable/G root:FC_Analysis:Temperature = 23
	Variable/G root:FC_Analysis:Fits:WLC:PersistenceLength=0.4
	Variable/G root:FC_Analysis:Fits:WLC:ContourLength=100
	Variable/G root:FC_Analysis:Fits:WLC:ContourLengthIncrement=23.56
	Variable/G root:FC_Analysis:Fits:WLC:FoldedLength=3.8
	Variable/G root:FC_Analysis:Fits:WLC:Linker
	Variable/G root:FC_Analysis:Fits:WLC:Refolded=0
	Variable/G root:FC_Analysis:Fits:WLC:Units=3
	Variable/G root:FC_Analysis:Fits:WLC:F_Error=0
	Variable/G root:FC_Analysis:Fits:WLC:Successful=0
	Variable/G root:FC_Analysis:Initial=0
	Variable/G root:FC_Analysis:FCNextWaveNumber
	Variable/G root:FC_Analysis:FillUpFlag=0
	Variable/G root:FC_Analysis:Steps:MinStep = 5	//nm
	Variable/G root:FC_Analysis:Steps:SlideAverage = 10
	Variable/G root:FC_Analysis:Steps:Deviation = 0.3	//nm
	if ( ! WaveExists(root:FC_Analysis:Events))
		Make/N=(1000, 20) root:FC_Analysis:Events
	endif
	if ( ! WaveExists(root:FC_Analysis:TimesWave))
		Make/N=(0,24) root:FC_Analysis:TimesWave
	endif
	if ( ! WaveExists(root:FC_Analysis:StepsWave))
		Make/N=(0,24) root:FC_Analysis:StepsWave
	endif
	if(!WaveExists(root:FC_Analysis:StepsNameWave))
		Make/T/N=0 root:FC_Analysis:StepsNameWave
	endif
	if(!WaveExists(root:FC_Analysis:Fits:GoodP))
		Make/N=200 root:FC_Analysis:Fits:GoodP
	endif
	if(!WaveExists(root:FC_Analysis:Fits:SuccessP))
		Make/N=200 root:FC_Analysis:Fits:SuccessP
	endif
End

Function AFMAnalysisPanel()
	PauseUpdate; Silent 1		// building window...
	DoWindow/F/K Analysispanel
	NewPanel/K=1/W=(900,60,1000,770)  as "AFM Analysis"
	DoWindow/C Analysispanel
	SetWindow Analysispanel,hook(testhook)=KeyboardPanelHook

	TabControl AnalysisTabs,pos={5,5},size={290,700},proc=AnalysisDisableProc
	TabControl AnalysisTabs,tabLabel(0)="     FX     "
	TabControl AnalysisTabs,tabLabel(1)="         FC         ",value= 0  
	//value=0 is important to set the first tab to calibrate!!!!!! If changed, the last line of this function must be changed!!!!!!
	
	//********************************************************************************************************************************
	//FX Analysis tab group items
	GroupBox boxFXDisplay,pos={10,25},size={280,125},title="Display",font="Times New Roman"
	Button buttonFXKill,pos={20,50},size={16,16},proc=KillFXAnalysisGraph,title=""
	SetVariable setvarFXstart,pos={40,50},size={75,16},proc=Display_FX_Recordings,title="start"
	SetVariable setvarFXstart,limits={0,10000,1},value= root:FX_Analysis:DisplayStartNumber
	SetVariable setvarFXdisplay,pos={120,50},size={90,16},proc=Display_FX_Recordings,title="display #"
	SetVariable setvarFXdisplay,limits={0,inf,1},value= root:FX_Analysis:DisplayNumber
	CheckBox checkFXUncorr,pos={220,50},size={120,16},proc=Display_FXUncorrected,title="Uncorr?"
	CheckBox checkFXUncorr,variable= root:FX_Analysis:FXDisplayUncorrected
	ValDisplay valdispFXSC,pos={20,75},size={100,16},title="SC (pN/nm)",value= #"root:FX_Analysis:SpringConstant"
	ValDisplay valdispFXAmp,pos={130,75},size={120,16},title="Amplitude (nm)",value= #"root:FX_Analysis:ExcursionSize"
	ValDisplay valdispFXRate,pos={20,100},size={100,16},title="Rate (nm/s)",value= #"root:FX_Analysis:ExcursionRate"
	SetVariable setvarFXTemp,pos={130,100},size={120,16},title="Temperature (C)"
	SetVariable setvarFXTemp,limits={-10,100,0},value= root:FX_Analysis:Temperature
	Button buttonFXCorrect,pos={20,125},size={50,18},proc=FX_CorrectOne,title="Correct"
	Button buttonFXCorrAll,pos={80,125},size={60,18},proc=FX_CorrectAll,title="Correct All"
	CheckBox checkPoly,pos={150,127},size={70,18},title="Polynomial?"
	CheckBox checkPoly,variable= root:FX_Analysis:CorrectPolynomial
	Button buttonFXExport,pos={230,125},size={50,18},proc=FX_Export,title="Export"
	
	GroupBox boxFXElasticity,pos={10,150},size={280,350},title="Polymer Elasticity",font="Times New Roman"
	GroupBox boxFXElasticity, fSize=12
	PopupMenu popupFXModel,pos={20,173},size={90,16},proc=FX_SetElasticityModel,title="Model"
	PopupMenu popupFXModel,mode=1,popvalue="WLC",value= #"\"WLC;WLC with Se;FJC; FJC with Se;FRC/EJC; FRC with Se;TC\""
	Button buttonFXUpdate,pos={160,175},size={50,18},proc=FX_UpdateFits,title="update"
	Button buttonFXclear,	pos={220,175},size={50,18},proc=FX_ClearFits,title="clear fits"
	CheckBox checkFXSep,pos={20,200},size={120,16},proc=FX_FitEachPeak,title="Fit peaks separately?"
	CheckBox checkFXSep,variable= root:FX_Analysis:Fits:Separate
	CheckBox checkFXTag,pos={150,200},size={44,16},proc=FX_CheckTag,title="tags?",value= 0
	Button buttonFXbase,	pos={210,200},size={60,18},proc=FX_Baseline,title="\f04\\K(65280,0,0)B\\K(0,0,0)\\f00aseline"
	SetVariable setvarFXCurves,pos={20,225},size={85,16},proc=FX_CallUpdate,title="# curves"
	SetVariable setvarFXCurves,limits={1,40,1},value= root:FX_Analysis:Fits:Variables:NumberOfCurves
	SetVariable setvarFXDelta,pos={110,225},size={85,16},proc=FX_CallUpdate,title="Delta"
	SetVariable setvarFXDelta,limits={-200,200,1},value= root:FX_Analysis:Fits:Variables:ContourLengthincrement
	PopupMenu popupFXFit,pos={200,223},size={60,16},proc=FX_SelectFit,title="Fit"
	PopupMenu popupFXFit,mode=2,popvalue="A",value= #"\"none;A;A to B\""	
	SetVariable setvarFXp,pos={20,250},size={105,16},proc=FX_CallUpdate,title="p (nm) "
	SetVariable setvarFXp,limits={0,50,0.01},value= root:FX_Analysis:Fits:Variables:PersistenceLength
	Slider sliderFXP,pos={20,275},size={250,50},proc=SetP
	Slider sliderFXP,limits={0,1.5,0.01},variable= root:FX_Analysis:Fits:Variables:PersistenceLength,vert= 0,ticks= 20
	SetVariable setvarFXAngle,pos={140,250},size={105,16},proc=FX_CallUpdate,title="Angle"
	SetVariable setvarFXAngle,limits={0,90,1},value= root:FX_Analysis:Fits:Variables:BondAngle
	Slider sliderFXAngle,pos={20,275},size={250,50},proc=SetAngle
	Slider sliderFXAngle,limits={0,90,1},variable= root:FX_Analysis:Fits:Variables:BondAngle,vert= 0,ticks= 20
	SetVariable setvarFXThick,pos={135,250},size={130,16},proc=FX_CallUpdate,title="Chain Thick (nm)"
	SetVariable setvarFXThick,limits={0,2,0.1},value= root:FX_Analysis:Fits:Variables:ChainThickness
	Slider sliderFXThick,pos={20,275},size={250,50},proc=SetThickness
	Slider sliderFXThick,limits={0,2,0.01},variable= root:FX_Analysis:Fits:Variables:ChainThickness,vert= 0,ticks= 20
	SetVariable setvarFXL,pos={20,325},size={105,16},proc=FX_CallUpdate,title="L (nm) "
	SetVariable setvarFXL,limits={0,1000,0.5},value= root:FX_Analysis:Fits:Variables:ContourLength
	Slider sliderFXL,pos={20,350},size={250,50},proc=SetL
	Slider sliderFXL,limits={0,1000,1},variable= root:FX_Analysis:Fits:Variables:ContourLength,vert= 0,ticks= 20	
	SetVariable setvarSe,pos={20,400},size={120,16},proc=FX_CallUpdate,title="Se (pN/nm) "
	SetVariable setvarSe,limits={0,100000,10},value= root:FX_Analysis:Fits:Variables:SegmentElasticity
	Slider sliderFXSe,pos={20,425},size={250,50},proc=SetSe
	Slider sliderFXSe,limits={0,100000,1},variable= root:FX_Analysis:Fits:Variables:SegmentElasticity,vert= 0,ticks= 20
	SetVariable setvarFXc,pos={160,400},size={60,16},proc=FX_CallUpdate,title="c"
	SetVariable setvarFXc,limits={1,2,0.1},value= root:FX_Analysis:Fits:Variables:c
	SetVariable setvarFXSep,pos={20,400},size={115,16},proc=FX_CallUpdate,title="Disc Sep(nm)"
	SetVariable setvarFXSep,limits={0,2,0.1},value= root:FX_Analysis:Fits:Variables:DiscSeparation	
	Slider sliderFXSep,pos={20,425},size={250,50},proc=SetSeparation
	Slider sliderFXSep,limits={0,2,0.01},variable= root:FX_Analysis:Fits:Variables:DiscSeparation,vert= 0,ticks= 20
	
	GroupBox boxFXPeaks,pos={10,500},size={280,75},title="Fit Peaks Table",font="Times New Roman"
	Button buttonFXpeakF,pos={20,525},size={50,18},proc=FX_FindPeaksForward,title="Peak F"
	Button buttonFXpeakB,pos={80,525},size={50,18},proc=FX_FindPeaksBackward,title="Peak B"
	SetVariable setvarFXMinPeak,pos={140,525},size={120,16},title="Min Peak (pN)"
	SetVariable setvarFXMinPeak,limits={0,inf,20},value= root:FX_Analysis:PeakDetectorLevel
	SetVariable setvarFXPeakSmooth,pos={140,550},size={120,16},title="Smooth (odd #)"
	SetVariable setvarFXPeakSmooth,limits={1,inf,2},value= root:FX_Analysis:PeakDetectorSmooth
	Button buttonFXEnter,pos={50,550},size={50,18},proc=FX_EnterValues,title="E\f04\\K(65280,0,0)n\\K(0,0,0)\\f00ter"
	
	GroupBox boxFXHist,pos={10,575},size={280,75},title="Misc Analysis (WLC only)",font="Times New Roman"
	Button buttonFXp,pos={20,480},size={50,18},proc=FX_Histp,title="p Hist"															//cambie desde 600
	Button buttonFXL,pos={80,480},size={50,18},proc=FX_HistL,title="L\Bc\M Hist"													//cambie desde 600
	Button buttonFXdL,pos={140,480},size={60,18},proc=FX_HistDelta,title="\F'Symbol'D\F'MS Shell Dlg'L\Bc\M Hist"		//cambie desde 600
	Button buttonFXForces,pos={210,480},size={70,18},proc=FX_HistForces,title="Forces Hist"									//cambie desde 600
	Button buttonFXPvsF,pos={20,624},size={70,18},proc=FX_pvsF,title="Find p vs F"
	
	GroupBox boxFXDelete,pos={10,430},size={280,50},title="FX Delete",font="Times New Roman" //cambie desde 650
	SetVariable setvarFXfrom,pos={20,450},size={90,16},title="From"									//cambie desde 675
	SetVariable setvarFXfrom,limits={0,10000,1},value= root:FX_Analysis:DisplayStartNumber
	SetVariable setvarFXto,pos={125,450},size={80,16},title="To"                              //cambie desde 675
	SetVariable setvarFXto,value= root:FX_Analysis:nextwavenumber  
	Button buttonFXDelete,pos={220,450},size={50,18},proc=FX_DeleteWaves,title="Delete!"      //cambie desde 675
	Button buttonFXDelete,help={"THIS CANNOT BE UNDONE!!!!!!!!!!"}
		
	//********************************************************************************************************************************
	//FC analysis tab group items
	GroupBox boxFCDisplay,pos={10,25},size={280,125},disable=1,title="Display",font="Times New Roman"
	Button buttonFCKill,pos={20,50},size={16,16},proc=KillFCAnalysisGraph,title=""
	SetVariable setvarFCRecord,pos={40,50},size={75,16},disable=1,proc=FC_UpdatePlot,title="start"
	SetVariable setvarFCRecord,limits={0,10000,1},value= root:FC_Analysis:FCDisplayStartNumber
	SetVariable setvarFCDisplay,pos={120,50},size={90,16},disable=1,proc=FC_UpdatePlot,title="display #"
	SetVariable setvarFCDisplay,limits={0,inf,1},value= root:FC_Analysis:FCDisplayNumber
	CheckBox checkFCUncorr,pos={220,50},size={120,16},proc=Display_FCUncorrected,title="Uncorr?"
	CheckBox checkFCUncorr,value= 0	
	ValDisplay valdispFCSC,pos={20,75},size={100,16},title="SC (pN/nm)",value= #"root:FC_Analysis:SpringConstant"
	SetVariable setvarFCType,pos={130,75},size={150,16},title="Exp Type",value= root:FC_Analysis:ExpType
	SetVariable setvarFCTemp,pos={130,100},size={120,16},title="Temperature (C)"
	SetVariable setvarFCTemp,limits={-10,100,0},value= root:FC_Analysis:Temperature
	Button buttonFCCorrect,pos={20,125},size={50,18},proc=FC_CorrectOne,title="Correct"
	Button buttonFCCorrAll,pos={80,125},size={60,18},proc=FC_CorrectAll,title="Correct All"
	Button buttonFCExport,pos={230,125},size={50,18},proc=FC_Export,title="\\f04\\K(65280,0,0)E\\K(0,0,0)\\f00xport"
	
	GroupBox boxFCWLC,pos={8,150},size={280,175},disable=1,title="WLC Analysis",font="Times New Roman"
	SetVariable setvarFCUpdate,pos={20,175},size={90,16},disable=1,proc=FC_UpdateWLC,title="p (nm)"
	SetVariable setvarFCUpdate,limits={0,50,0.01},value= root:FC_Analysis:Fits:WLC:PersistenceLength
	SetVariable setvarFCFolded,pos={150,175},size={110,16},disable=1,title="Folded L (nm)"
	SetVariable setvarFCFolded,limits={0,50,0.1},value= root:FC_Analysis:Fits:WLC:FoldedLength
	SetVariable setvarFCDeltaL,pos={20,200},size={90,16},disable=1,proc=FC_UpdateWLC,title="dL (nm)"
	SetVariable setvarFCDeltaL,limits={-100,100,0.5},value= root:FC_Analysis:Fits:WLC:ContourLengthIncrement
	SetVariable setvarFCRefolded,pos={150,200},size={90,16},disable=1,title="Refolded"
	SetVariable setvarFCRefolded,limits={0,50,1},value= root:FC_Analysis:Fits:WLC:Refolded
	SetVariable setvarFCLinker,pos={20,225},size={110,16},disable=1,proc=FC_UpdateWLC,title="Linker (nm)"
	SetVariable setvarFCLinker,limits={-500,500,1},value= root:FC_Analysis:Fits:WLC:Linker
	SetVariable setvarFCUnits,pos={150,225},size={80,16},disable=1,title="# units"
	SetVariable setvarFCUnits,limits={0,50,1},value= root:FC_Analysis:Fits:WLC:Units
	SetVariable setvarFCError,pos={20,250},size={110,16},disable=1,proc=FC_UpdateWLC,title="Error in Force"
	SetVariable setvarFCError,limits={-100,100,1},value= root:FC_Analysis:Fits:WLC:F_Error
	CheckBox checkFCInitial,pos={150,250},size={118,14},disable=1,title="Initial Unfolding only?"
	CheckBox checkFCInitial,variable= root:FC_Analysis:Initial
	Button buttonFCDisplayWLC,pos={20,273},size={75,18},disable=1,proc=FC_ButtonWLC,title="Display WLC"
	Button buttonFCFindP,pos={100,273},size={45,18},disable=1,proc=FC_P_Find,title="Find p"	
	Button buttonFCPvsF,pos={150,273},size={40,18},disable=1,proc=FC_P_Cut,title="p vs F"
	Button buttonFCplotP,pos={195,273},size={35,18},disable=1,proc=FC_P_Plot,title="Plot p"
	Button buttonFCpHist,pos={235,273},size={40,18},disable=1,proc=FC_P_Hist,title="p Hist"
	Button buttonFCxNorm,pos={100,298},size={45,18},disable=1,proc=FC_xNorm,title="L\BN"
	Button buttonFCplotxNorm,pos={150,298},size={45,18},disable=1,proc=FC_xNorm_Plot,title="plot L\BN"	
	Button buttonFCxNormHist,pos={200,298},size={45,18},disable=1,proc=FC_xNorm_Hist,title="L\BN\M Hist"
	
	GroupBox boxFCSteps,pos={10,325},size={280,125},title="Detect Steps",font="Times New Roman"
	Button buttonFCStepDetect,pos={20,350},size={80,18},proc=FC_DetectSteps,title="\\f04\\K(65280,0,0)D\\K(0,0,0)\\f00etect Steps"
	SetVariable setvarFCMinStep,pos={110,350},size={130,16},disable=1,title="Min Stepsize (nm)"
	SetVariable setvarFCMinStep,limits={0,10,1},value= root:FC_Analysis:Steps:MinStep
	Button buttonFCAddStep,pos={20,375},size={75,18},proc=FC_AddStep,title="Add Step"
	Button buttonFCDeleteStep,pos={105,375},size={75,18},proc=FC_DeleteStep,title="Delete Step"
	Button buttonFCDeleteAllSteps,pos={190,375},size={90,18},proc=FC_DeleteAllSteps,title="Delete All Steps"
	SetVariable setvarFCSlide,pos={20,400},size={110,16},disable=1,title="Slide Size (*2)"
	SetVariable setvarFCSlide,limits={0,12,1},value= root:FC_Analysis:Steps:SlideAverage
	SetVariable setvarFCDev,pos={140,400},size={110,16},disable=1,title="Stingency"
	SetVariable setvarFCDev,limits={0,2,0.1},value= root:FC_Analysis:Steps:Deviation
	Button buttonFCStepHeightHist,pos={20,425},size={90,18},proc=FC_CompileStepHeights,title="Step Height Hist"
	Button buttonFCUnfoldingTimes,pos={120,425},size={130,18},proc=FC_CompileUnfoldingTimes,title="Compile Unfolding Times"
		
	GroupBox boxFCAddSteps,pos={210,450},size={280,130},title="Sum Traces",font="Times New Roman"
	Button buttonGetTrace,pos={210,460},size={65,18},proc=FC_Traces_Cut,title="Cut Trace"
//	SetVariable setvarSource,pos={20,475},size={180,20},title="Source Folder",value= root:FC_Analysis:SumTraces:SourceFolder
	SetVariable setvarDest,pos={20,500},size={255,20},title="Destination",value= root:FC_Analysis:SumTraces:DestinationFolder
	Button buttonSumTrace,pos={180,460},size={65,18},proc=FC_Traces_Sum,title="Sum'em up"
	Button buttonBootStrap,pos={20,460},size={65,18},proc=BootStrapAverageWaves,title="BootStrap"
	SetVariable BootStrapSetIterations,pos={50,550},size={150,20},title="Iterations",value= root:FC_Analysis:BootStrapNumIterations,bodyWidth=50
	CheckBox CheckBootStrap,variable= root:FC_Analysis:BootStrapConstrain,pos={205,550},size={50,14},title="Constrained?"
	
	CheckBox FillUpCheckBox,pos={104,527},size={50,14},title="FillUp?"
	CheckBox FillUpCheckBox,variable= root:FC_Analysis:FillUpFlag
	SetVariable FC_AvgTracePrefix,pos={162,527},size={120,16},title="Name prefix"
	SetVariable FC_AvgTracePrefix,value= root:FC_Analysis:SumTraces:AvgTracePrefix,bodyWidth= 60
	
	GroupBox boxFCDelete,pos={10,460},size={280,50},title="FC Delete",font="Times New Roman"
	SetVariable setvarFCFrom,pos={20,470},size={90,16},title="From"
	SetVariable setvarFCFrom,limits={0,10000,1},value= root:FC_Analysis:FCDisplayStartNumber
	SetVariable setvarFCTo,pos={125,470},size={90,16},title="To"
	SetVariable setvarFCTo,limits={0,10000,1},value= root:FC_Analysis:FCNextWaveNumber
	Button buttonFCDelete,pos={125,460},size={50,18},proc=FC_DeleteWaves,title="\\f04\\K(65280,0,0)Delete\\K(0,0,0)\\f00!"
	Button buttonFCDelete,help={"THIS CANNOT BE UNDONE!!!!!!!!!!"}
	
	AnalysisDisableProc("FX",0) 
	DetectWavenames()
	LabelFitParamMatrix()
End
//********************************************************************************************************************************

Function Analysisdisableproc(name,tab)
	string name
	variable tab
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR model = root:FX_Analysis:PolymerElasticityModel
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	//FX analysis tab group items for disable
	GroupBox boxFXDisplay, disable= (tab!=0)
	Button buttonFXKill, disable= (tab!=0)
	SetVariable setvarFXstart, disable= (tab!=0)
	SetVariable setvarFXdisplay, disable= (tab!=0)
	ValDisplay valdispFXSC, disable= (tab!=0)
	ValDisplay valdispFXAmp, disable= (tab!=0)
	ValDisplay valdispFXRate, disable= (tab!=0)
	SetVariable setvarFXTemp, disable= (tab!=0)
	Button buttonFXCorrect, disable= (tab!=0)
	Button buttonFXCorrAll, disable= (tab!=0)
	CheckBox checkPoly, disable= (tab!=0)
	CheckBox checkFXUncorr, disable= (tab!=0)
	Button buttonFXExport, disable= (tab!=0)
	
	GroupBox boxFXElasticity, disable= (tab!=0)
	PopupMenu popupFXModel, disable= (tab!=0)	
	Button buttonFXUpdate, disable= (tab!=0)
	Button buttonFXclear, disable= (tab!=0)
	CheckBox checkFXSep, disable= (tab!=0)
	CheckBox checkFXTag, disable= (tab!=0)
	Button buttonFXbase, disable= (tab!=0)
	
	if(tab==0)
		if (fitmode == 0)		
			SetVariable setvarFXCurves, disable= (tab!=0)
			SetVariable setvarFXDelta, disable= (tab!=0)
		else
			SetVariable setvarFXCurves, disable= 1
			SetVariable setvarFXDelta, disable= 2
		endif	
		FX_ModelDisplay()
	else	
		SetVariable setvarFXCurves, disable= (tab!=0)
		SetVariable setvarFXDelta, disable= (tab!=0)
		PopupMenu popupFXFit, disable= (tab!=0)
		SetVariable setvarFXp, disable= (tab!=0)
		Slider sliderFXP, disable= (tab!=0)
		SetVariable setvarFXAngle, disable= (tab!=0)
		Slider sliderFXAngle, disable= (tab!=0)
		SetVariable setvarFXThick, disable= (tab!=0)
		Slider sliderFXThick, disable= (tab!=0)
		SetVariable setvarFXL, disable= (tab!=0)
		Slider sliderFXL, disable= (tab!=0)	
		SetVariable setvarSe, disable= (tab!=0)
		Slider sliderFXSe, disable= (tab!=0)
		SetVariable setvarFXc, disable= (tab!=0)		
		SetVariable setvarFXSep, disable= (tab!=0)
		Slider sliderFXSep, disable= (tab!=0)
	endif
	
	GroupBox boxFXPeaks, disable= (tab!=0)
	Button buttonFXpeakF, disable= (tab!=0)
	Button buttonFXpeakB, disable= (tab!=0)
	SetVariable setvarFXMinPeak, disable= (tab!=0)
	SetVariable setvarFXPeakSmooth, disable= (tab!=0)
	Button buttonFXEnter, disable= (tab!=0)
	
	GroupBox boxFXHist, disable= (tab!=0)
	Button buttonFXp, disable= (tab!=0)
	Button buttonFXL, disable= (tab!=0)
	Button buttonFXdL, disable= (tab!=0)
	Button buttonFXForces, disable= (tab!=0)
	Button buttonFXPvsF, disable= (tab!=0)
	
	GroupBox boxFXDelete, disable= (tab!=0)
	SetVariable setvarFXfrom, disable= (tab!=0)
	SetVariable setvarFXto, disable= (tab!=0)
	Button buttonFXDelete, disable= (tab!=0)
	
	//FC analysis tab group items for disable
	GroupBox boxFCDisplay, disable= (tab!=1)
	Button buttonFCKill, disable= (tab!=1)
	SetVariable setvarFCRecord, disable= (tab!=1)
	SetVariable setvarFCDisplay, disable= (tab!=1)
	CheckBox checkFCUncorr, disable= (tab!=1)
	ValDisplay valdispFCSC, disable= (tab!=1)
	SetVariable setvarFCType, disable= (tab!=1)
	SetVariable setvarFCTemp, disable= (tab!=1)
	Button buttonFCCorrect, disable= (tab!=1)
	Button buttonFCCorrAll, disable= (tab!=1)
	Button buttonFCExport, disable= (tab!=1)
	
	GroupBox boxFCWLC, disable= (tab!=1)
	SetVariable setvarFCUpdate, disable= (tab!=1)
	SetVariable setvarFCFolded, disable= (tab!=1)
	SetVariable setvarFCDeltaL, disable= (tab!=1)
	SetVariable setvarFCRefolded, disable= (tab!=1)
	SetVariable setvarFCLinker, disable= (tab!=1)
	SetVariable setvarFCUnits, disable= (tab!=1)
	SetVariable setvarFCError, disable= (tab!=1)
	CheckBox checkFCInitial, disable= (tab!=1)
	Button buttonFCDisplayWLC, disable= (tab!=1)
	Button buttonFCPvsF, disable= (tab!=1)
	Button buttonFCFindP, disable= (tab!=1)
	Button buttonFCplotP, disable= (tab!=1)
	Button buttonFCpHist, disable= (tab!=1)
	Button buttonFCxNorm, disable= (tab!=1)
	Button buttonFCplotxNorm, disable= (tab!=1)
	Button buttonFCxNormHist, disable= (tab!=1)
	
	GroupBox boxFCSteps, disable= (tab!=1)
	Button buttonFCStepDetect, disable= (tab!=1)
	SetVariable setvarFCMinStep, disable= (tab!=1)
	Button buttonFCAddStep,disable= (tab!=1)
	Button buttonFCDeleteStep,disable= (tab!=1)
	Button buttonFCDeleteAllSteps,disable= (tab!=1)
	SetVariable setvarFCSlide,disable= (tab!=1)
	SetVariable setvarFCDev,disable= (tab!=1)
	Button buttonFCStepHeightHist,disable= (tab!=1)
	Button buttonFCUnfoldingTimes,disable= (tab!=1)
	
	GroupBox boxFCAddSteps, disable= (tab!=1)
	Button buttonGetTrace, disable= (tab!=1)
//	SetVariable setvarSource, disable= (tab!=1)
	SetVariable setvarDest, disable= (tab!=1)
	Button buttonSumTrace, disable= (tab!=1)
	CheckBox FillUpCheckBox, disable= (tab!=1)
	SetVariable FC_AvgTracePrefix, disable= (tab!=1)
	
	GroupBox boxFCDelete, disable= (tab!=1)
	SetVariable setvarFCFrom, disable= (tab!=1)
	SetVariable setvarFCTo, disable= (tab!=1)
	Button buttonFCDelete, disable= (tab!=1)
	
	Button buttonBootStrap, disable= (tab!=1)
	SetVariable BootStrapSetIterations, disable= (tab!=1)
	CheckBox CheckBootStrap, disable= (tab!=1)

End

//********************************************************************************************************************************
Function DetectWavenames()
	NVAR FXInfoFlag = root:FX_Analysis:FXInfoFlag
	NVAR FCInfoFlag = root:FC_Analysis:FCInfoFlag
	SVAR Force = root:FX_Analysis:ForceWaveName
	SVAR Length = root:FX_Analysis:LengthWaveName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	String FullName, Info
	
	FullName = "ExtensionRaw_F0"
	if (WaveExists($FullName) == 1)		
		Length = "ExtensionRaw_"
		Force = "ForceRaw_"
	else
		Length = "Extension_"		// if ExtensionRaw_0 doesn't exist -> old experiment type
		Force = "Force_"
	endif
	FullName = Length + "F0"
	if (WaveExists($FullName) == 1)
		Info = Note($FullName)
		if (strlen(Info) > 0)
			FXInfoFlag = 1	// Note exists
		else
			FXInfoFlag = 0	// Note doesn't exist
		endif
	else
		FXInfoFlag = 0
	endif
	
	FullName = "FC_Force0"
	if (WaveExists($FullName) == 1)		
		ForceName = "FC_Force"
		LengthName = "FC_Length"
	else
		ForceName = "Ramp_Force_Wave"
		LengthName = "Ramp_Length_Wave"
	endif
	FullName = ForceName + "0"
	if (WaveExists($FullName) == 1)	
		Info = Note($FullName)
		if (strlen(Info) > 0)
			FCInfoFlag = 1	// Note exists
		else
			FCInfoFlag = 0	// Note doesn't exist
		endif
	endif
End

//********************************************************************************************************************************
Function LabelFitParamMatrix()
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Variable i
	String Name
	for (i = 0; i < 1000; i += 1)	// label rows
		Name = "Trace" + num2str(i)
		SetDimLabel 0, i, $Name, FitParam
	endfor
	for (i = 0; i < 20; i += 1)	// label columns
		Name = "Peak" + num2str(i)
		SetDimLabel 1, i, $Name, FitParam
	endfor
	
	SetDimLabel 2, 0, PeakPointNumber, FitParam
	SetDimLabel 2, 1, Force, FitParam
	SetDimLabel 2, 2, CursorA, FitParam
	SetDimLabel 2, 3, CursorB, FitParam
	SetDimLabel 2, 4, nCurves, FitParam
	SetDimLabel 2, 5, Model, FitParam
	
	SetDimLabel 2, 6, WLC_p, FitParam
	SetDimLabel 2, 7, WLC_L, FitParam
	SetDimLabel 2, 8, WLC_Delta, FitParam
	
	SetDimLabel 2, 9, WLCSe_p, FitParam
	SetDimLabel 2, 10, WLCSe_L, FitParam
	SetDimLabel 2, 11, WLCSe_Delta, FitParam
	SetDimLabel 2, 12, WLCSe_Se, FitParam
	
	SetDimLabel 2, 13, FJC_Kuhn, FitParam
	SetDimLabel 2, 14, FJC_L, FitParam
	SetDimLabel 2, 15, FJC_Delta, FitParam
	
	SetDimLabel 2, 16, FJCSe_Kuhn, FitParam
	SetDimLabel 2, 17, FJCSe_L, FitParam
	SetDimLabel 2, 18, FJCSe_Delta, FitParam
	SetDimLabel 2, 19, FJCSe_Se, FitParam
	
	SetDimLabel 2, 20, FRC_p, FitParam
	SetDimLabel 2, 21, FRC_L, FitParam
	SetDimLabel 2, 22, FRC_Delta, FitParam
	SetDimLabel 2, 23, FRC_Angle, FitParam
	SetDimLabel 2, 24, FRC_c, FitParam
	SetDimLabel 2, 25, FRC_b, FitParam
	
	SetDimLabel 2, 26, FRCSe_p, FitParam
	SetDimLabel 2, 27, FRCSe_L, FitParam
	SetDimLabel 2, 28, FRCSe_Delta, FitParam
	SetDimLabel 2, 29, FRCSe_Angle, FitParam
	SetDimLabel 2, 30, FRCSe_c, FitParam
	SetDimLabel 2, 31, FRCSe_b, FitParam
	SetDimLabel 2, 32, FRCSe_Se, FitParam
	
	SetDimLabel 2, 33, TC_p, FitParam
	SetDimLabel 2, 34, TC_L, FitParam
	SetDimLabel 2, 35, TC_Delta, FitParam
	SetDimLabel 2, 36, TC_Thick, FitParam
	SetDimLabel 2, 37, TC_Sep, FitParam
	
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Override Function PeriodicUpdate(T)
	Variable T
	NVAR/Z LastUpdatetime=root:LastUpdatetime
	If(!NVAR_Exists(LastUpdatetime))
		Variable/G root:LastUpdatetime=DateTime
		return 0
	EndIf
	Variable TimeNow=DateTime
	If(TimeNow-LastUpdatetime>=T)
		DoUpdate
		PauseUpdate
		LastUpdateTime=TimeNow
		return 1
	Else 
		Return 0
	EndIf
End


//*******************************************************************************************************************************************************************
Function KeyboardPanelHook(s)	// Capture keyboard events in Analysis panel. Created by Rodofo Hermans
	STRUCT WMWinHookStruct &s
	
//	if(s.eventCode==hook_keyboard)
	NVAR DisplayFCNumber = root:FC_Analysis:FCDisplayStartNumber
	NVAR DisplayFXNumber = root:FX_Analysis:DisplayStartNumber
	NVAR FCLevel = root:FC_Analysis:FCLevel
	NVAR FCstepSize =  root:FC_Analysis:FCstepSize
	NVAR FCstepForce =  root:FC_Analysis:FCstepForce
	NVAR Uncorrected = root:FC_Analysis:FCDisplayUncorrected
	SVAR LengthTraceName = root:FC_Analysis:LengthWaveName
	Variable MousePoint, MousePointNew, RightClick, NewFCLevel
	//david
	Variable AxeCoord
	SVAR ForceTraceName = root:FC_Analysis:ForceWaveName
	
	
		if(stringmatch(winname(0,3),"ForceClampAnalysis"))
		switch(s.eventCode)
			case hook_mousedown:
				RightClick= (s.eventMod & (2^4))			 // bit 4, detect right click
				if(!RightClick)
					SetDataFolder root:Data
					string Length_Wave = "root:FC_Analysis:Shift:shift_" + LengthTraceName + num2str(DisplayFCNumber)
					
						//if corrected trace
					if(waveexists($Length_Wave) && Uncorrected == 0)
						wave current_trace = $Length_Wave
						
						//if uncorrected trace
					else
						wave current_trace = root:Data:$(LengthTraceName + num2str(DisplayFCNumber))
					
					endif
					string forcetrace = "root:FC_Analysis:Shift:filtered_FC_Force" + num2str(DisplayFCNumber)
					wave force = $forcetrace

					MousePoint = str2num(stringbykey("HITPOINT",Tracefrompixel(s.mouseLoc.h,s.mouseLoc.v,""),":",";"))
					NewFCLevel = mean(current_trace, pnt2x(current_trace, MousePoint-10), pnt2x(current_trace, MousePoint+10)) 		//average over 20 points
					FCstepSize = NewFCLevel - FCLevel
					FCLevel = NewFCLevel
					
					MousePointNew=mean(force, AxisValFromPixel("","bottom",s.mouseLoc.h-5), AxisValFromPixel("","bottom",s.mouseLoc.h+5))
					print FCstepSize,(FCstepForce+MousePointNew)/2
					FCstepForce = MousePointNew
						
					//print Force[MousePoint]
					//print pnt2x(current_trace, MousePoint)
					//AxeCoord = AxisValFromPixel("","bottom",s.mouseLoc.h)
					//print force(AxeCoord)
					//print AxeCoord
					//FindPeak/R=[67800,69500] force 

				 				
				endif
				break	

				
//			case hook_mousemoved:
//				MousePoint = str2num(stringbykey("HITPOINT",Tracefrompixel(s.mouseLoc.h,s.mouseLoc.v,""),":",";"))
//				if(numtype(MousePoint)!=2)
//					MousePoint = str2num(stringbykey("HITPOINT",Tracefrompixel(s.mouseLoc.h,s.mouseLoc.v,""),":",";"))
//					//sprintf TagText, "%.2f",cw[MousePoint]												//create tag
//					//Tag/C/N=text0/F=0/L=1 $CurrentWaveName, pnt2x(cw,MousePoint),TagText			//display tag
//				endif
//				rval= 0									// we have not taken over this event
//				break
				
			case hook_mouseup:
				break	
				
			case hook_keyboard:
				print s.keycode
				switch(s.keycode)
					case 109:								//key m=measure
						saveFCmeasure(FCstepSize, FCstepForce, DisplayFCNumber)
						break
					case 110:								//key n=no refolding
						saveFCmeasure(0, 0, DisplayFCNumber)
					case 102:								//key f=filter
						FC_ApplyFilter()
						break
					case 104:								//key h=hindered unfolding
						ModifyGraph/W=ForceClampAnalysis manTick(left)={0,11,0,0},manMinor(left)={0,0}
						break
					case 114:								//key r=red
						ModifyGraph/W=ForceClampAnalysis manTick(left)={0,14,0,0},manMinor(left)={0,0}
						break
					case 116:								//key t=twentyfive
						ModifyGraph/W=ForceClampAnalysis manTick(left)={0,25,0,0},manMinor(left)={0,0}
						break
				endswitch
			endswitch
		
		endif
		
		switch(s.keycode)
			case 31:		//key arrow down 
				if(DisplayFCNumber > 0)
					DisplayFCNumber -=1
					Display_FC_Recordings()
				endif
				break
			case 30:		//key arrow up
				DisplayFCNumber +=1
				Display_FC_Recordings()
				break
			case 100:	//key d
				FC_DetectStepsFilt() //FC_DetectSteps("KeyboardHook")
				break
			case 127:	//key 
				FC_DeleteWaves("KeyboardHook")
				break
			case 1:		//key
					DisplayFCNumber =0
					Display_FC_Recordings()
					
				break
			case 119:	//key w
				DisplayFXNumber +=1
				Display_FX_Recordings("",0,"","")
				break
			case 115:	//key s
				if(DisplayFXNumber > 0)	
					DisplayFXNumber -=1
					Display_FX_Recordings("",0,"","")
				endif
				break
			case 101:	//key e
				FC_Export("")
				break
			case 110:	//key n
				FX_EnterValues("")
				break
			case 98:		//keyb
				FX_Baseline("")
				break
		endswitch
//	endif
	return 0
End

//********************************************************************************************************************************
//Here begins the code for the FXA
//********************************************************************************************************************************

Function Display_FXUncorrected(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selelcted, 0 if not
	Display_FX_Recordings("",1,"","")
End

//********************************************************************************************************************************
Function Display_FX_Recordings(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr, varName
	NVAR DisplayNumber= root:FX_Analysis:DisplayNumber
	NVAR DisplayStartNumber=root:FX_Analysis:DisplayStartNumber
	NVAR ToWavenumber = root:FX_Analysis:nextwavenumber
	NVAR SC = root:FX_Analysis:SpringConstant
	NVAR Amplitude = root:FX_Analysis:ExcursionSize
	NVAR Rate = root:FX_Analysis:ExcursionRate
	NVAR Temp = root:FX_Analysis:Temperature
	NVAR p = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR Lc = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaLc = root:FX_Analysis:Fits:Variables:ContourLengthIncrement
	NVAR FXInfoFlag = root:FX_Analysis:FXInfoFlag
	NVAR Uncorrected = root:FX_Analysis:FXDisplayUncorrected
	variable i, shiftby=0
	String Extension_F, Extension_B, Force_F, Force_B, InfoNote=""
	String RawExt_F, RawExt_B
	SetVariable setvarFXstart limits={0,10000,DisplayNumber}
	SetDataFolder root:Data
	towavenumber = DisplayStartNumber + DisplayNumber - 1

	DoWindow/F ForceExtensionAnalysis
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K ForceExtensionAnalysis
	endif
	Display/W=(0,0,800,600)
	DoWindow/C ForceExtensionAnalysis
	SetWindow ForceExtensionAnalysis,hook(testhook)=KeyboardPanelHook 
	for(i = DisplayStartNumber; i < DisplayStartNumber+DisplayNumber; i += 1)
		SetDataFolder root:Data
		RawExt_F = "ExtensionRaw_F" + num2str(i)
		Extension_F = "Extension_F" + num2str(i)		
		if (waveexists($Extension_F) && Uncorrected == 0) 
			Extension_B = "Extension_B" + num2str(i)
			Force_F="Force_F"+num2str(i)
			Force_B="Force_B"+num2str(i)
			AppendToGraph $Force_F vs $Extension_F
			AppendToGraph $Force_B vs $Extension_B
			if (DisplayNumber > 1)
				SetAxis/A left
			else
				SetAxis left -100,500 
				SetAxis bottom -2, 500
			endif
			SetDataFolder root:FX_Analysis:Fits
			Wave FitParam
			if (FitParam[i][0][%CursorA] > 0)
				FX_LoadParameters()
			endif
			SetDataFolder root:Data
		elseif(waveexists($RawExt_F) || Uncorrected == 1)
			Extension_F = "ExtensionRaw_F" + num2str(i)
			Extension_B = "ExtensionRaw_B" + num2str(i)
			Force_F="ForceRaw_F"+num2str(i)
			Force_B="ForceRaw_B"+num2str(i)
			AppendToGraph $Force_F vs $Extension_F
			AppendToGraph $Force_B vs $Extension_B		
			SetAxis/A
		else
			SetDrawLayer/W=ForceExtensionAnalysis UserFront
			SetDrawEnv/W=ForceExtensionAnalysis xcoord=rel, ycoord =rel,fsize= 14, textrgb= (39168,39168,39168),textxjust= 1,textyjust= 1
			DrawText/W=ForceExtensionAnalysis  0.5,0.5 , "Trace does not exist!"
			return i
		endif
		shiftby=300*(i-DisplayStartNumber)
		ModifyGraph rgb($Force_B)=(0,15872,65280), grid(left)=1, lblMargin(left)=10
		ModifyGraph offset($Force_F)={0,shiftby}, offset($Force_B)={0,shiftby} 
		Label bottom "Extension (nm)"
		Label left "Force (pN)"			
		InfoNote = note($Extension_F)	
		if (FXInfoFlag == 1)
			SC = NumberByKey(" SC(pN/nm)", InfoNote, "=")
			Amplitude = NumberByKey(" Amplitude(nm)", InfoNote, "=")
			Rate = NumberByKey(" PullingRate(nm/s)", InfoNote, "=")
			if (SC > 0)
			else
				SC = NumberByKey(" SC", InfoNote, "=")
				Amplitude = NumberByKey(" Amplitude", InfoNote, "=")
				Rate = NumberByKey(" PullingRate", InfoNote, "=")
			endif 
			if (NumberByKey(" T(C)", InfoNote, "=") > -10000)
				Temp = NumberByKey(" T(C)", InfoNote, "=")
			else
				Temp = 23
			endif
		else
			NVAR GSC = root:Data:G_SpringConstant
			NVAR GAmplitude = root:Data:G_ExcursionSize
			NVAR GRate = root:Data:G_ExcursionRate
			SC = GSC
			Amplitude = GAmplitude
			Rate = GRate
		endif		
	endfor
	ShowInfo
	DoWindow/F Analysispanel 
End

//********************************************************************************************************************************
Function KillFXAnalysisGraph(ctrlName) : ButtonControl
	String ctrlName
	DoWindow/F ForceExtensionAnalysis
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K ForceExtensionAnalysis
	endif
End

//********************************************************************************************************************************
Function FX_CorrectAll(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayStartNumber = root:FX_Analysis:DisplayStartNumber
	String Extension
	Variable start = DisplayStartNumber
	DisplayStartNumber = 0
	SetDataFolder root:Data
	do
		FX_CorrectOne("")
		DisplayStartNumber += 1
		Extension = "ExtensionRaw_F" + num2str(DisplayStartNumber)
	while (WaveExists($Extension) != 0)
	DisplayStartNumber = start
	Display_FX_Recordings("",1,"","")
End

//********************************************************************************************************************************
// This corrects the extension for the spring constant and filters force and extension
Function FX_CorrectOne(ctrlName) : ButtonControl
	String ctrlName
	NVAR SC = root:FX_Analysis:SpringConstant
	NVAR i = root:FX_Analysis:DisplayStartNumber
	NVAR Polyn = root:FX_Analysis:CorrectPolynomial
	String Extension_F, Extension_B, RawExt_F, RawExt_B, Force_F, Force_B, RawForce_F, RawForce_B
	String FiltForceF, FiltForceB, FiltExtF, FiltExtB, InfoNote, command
	SetDataFolder root:Data
	Extension_F = "Extension_F" + num2str(i)
	Extension_B = "Extension_B" + num2str(i)
	RawExt_F = "ExtensionRaw_F" + num2str(i)
	RawExt_B = "ExtensionRaw_B" + num2str(i)
	Force_F = "Force_F" + num2str(i)
	Force_B = "Force_B" + num2str(i)
	RawForce_F = "ForceRaw_F" + num2str(i)
	RawForce_B = "ForceRaw_B" + num2str(i)
	FiltForceF = "ForceRaw_F" + num2str(i) + "Filt"
	FiltForceB = "ForceRaw_B" + num2str(i) + "Filt"
	FiltExtF = "Extension_F" + num2str(i) + "Filt"
	FiltExtB = "Extension_B" + num2str(i) + "Filt"
	InfoNote = note($RawForce_F)	
	if (strlen(Infonote) != 0)
		SC = NumberByKey(" SC(pN/nm)", InfoNote, "=")
		if (SC > 0)
		else
			SC = NumberByKey(" SC", InfoNote, "=")
		endif
	else
		NVAR DataSC = root:Data:G_SpringConstant
		SC = DataSC
	endif
	// Correct extension for cantilever displacement
	Wave RawForceF = $RawForce_F
	Wave RawForceB = $RawForce_B		
	Duplicate/O $RawExt_F, $Extension_F
	Duplicate/O $RawExt_B, $Extension_B
	Wave ExtF = $Extension_F
	Wave ExtB = $Extension_B	
	if (Polyn == 1)		// correct using polynomial fit to extension
		CurveFit/Q poly 3, $RawExt_F /D=ExtF
		CurveFit/Q poly 3, $RawExt_B /D=ExtB
	endif
	ExtF -= RawForceF/SC
	ExtB -= RawForceB/SC
	// Filter force and extension here
//	command = "ApplyFilterToData(\"" + RawForce_F + "\",\"kaiserLowPassFX900-1200\"," + num2str(1) + "," + num2str(0) +")"
//	Execute command
//	command = "ApplyFilterToData(\"" + RawForce_B + "\",\"kaiserLowPassFX900-1200\"," + num2str(1) + "," + num2str(0) +")"
//	Execute command
//	command = "ApplyFilterToData(\"" + Extension_F + "\",\"kaiserLowPassFX900-1200\"," + num2str(1) + "," + num2str(0) +")"
//	Execute command
//	command = "ApplyFilterToData(\"" + Extension_B + "\",\"kaiserLowPassFX900-1200\"," + num2str(1) + "," + num2str(0) +")"
//	Execute command
//	Wave filteredForceF = $FiltForceF, filteredForceB = $FiltForceB	
//	Wave filteredExtF = $FiltExtF, filteredExtB = $FiltExtB	
//	Duplicate/O filteredExtF, $Extension_F
//	Duplicate/O filteredExtB, $Extension_B
//	Duplicate/O filteredForceF, $Force_F
//	Duplicate/O filteredForceB, $Force_B
	Duplicate/O $RawForce_F, $Force_F
	Duplicate/O $RawForce_B, $Force_B
//	KillWaves/Z filteredExtF, filteredExtB, filteredForceF, filteredForceB
End

//********************************************************************************************************************************
Function FX_Export(ctrlName) : ButtonControl
	String ctrlName
	SVAR LengthName = root:FX_Analysis:LengthWaveName
	SVAR ForceName = root:FX_Analysis:ForceWaveName
	String Length, Force, ListWaves=""
	Variable from, to, i
	SetDataFolder root:FC_Analysis
	Prompt from, "Export from trace:"
	Prompt to, "to (included): "
	DoPrompt "Please enter values", from, to
	if (V_Flag)
		return -1
	endif
	for (i=from; i<=to; i+=1)
		ListWaves += LengthName + "F" + num2str(i) + ";"
		ListWaves += LengthName + "B" + num2str(i) + ";"
		ListWaves += ForceName + "F" + num2str(i) + ";"	
		ListWaves += ForceName + "B" + num2str(i) + ";"			
	endfor
	SetDataFolder root:Data
	Save/C/B ListWaves
End

//********************************************************************************************************************************
Function FXImportWaves()
	String Foldername="root:"
	Prompt Foldername, "Please enter folder (complete path) into which you would like to import the data (in case of name conflict existing waves are not overwritten):"
	DoPrompt "Destination folder", Foldername
	if (V_Flag)
		return 0		// user canceled
	endif
	if (DataFolderExists(Foldername) == 0)
		NewDataFolder $Foldername
	endif
	SetDataFolder $Foldername
	LoadData/D/I/Q
	
	DoAlert 1, "Do you want to move the data into root:Data: and rename them so that they are continuous?"
	if (V_Flag == 2)
		return 0
	endif
	// continue with moving and renaming
	Variable start=0
	Variable i, k, counter
	String Forcename="Force_", Lengthname="Extension_", List
	String Force_for_old, Force_back_old, Ext_for_old, Ext_back_old
	String Force_for_new, Force_back_new, Ext_for_new, Ext_back_new
	String WaveOrigin = "Origin of Waves"
	SetDataFolder $(Foldername)
	List = WaveList("ForceRaw*", ";", "")
	if( ItemsInList(List) > 0)
		ForceName = "ForceRaw_"
		LengthName = "ExtensionRaw_"
	endif	
	if (DataFolderExists ("root:Data") == 0)
		NewDataFolder root:Data
	endif
	DoWindow NotebookOrigin
	if (V_Flag == 1)
		DoWindow/f NotebookOrigin
	else
		NewNotebook/K=2/f=0/n=NotebookOrigin/W=(600,0,800,120) as WaveOrigin
	endif
	do
		Force_for_old = "root:Data:" + Forcename + "F" + num2str(start)
		start += 1
	while (Waveexists($Force_for_old) == 1)
	start -= 1	
	counter = 0
	for (i = 0; i < 500; i += 1)
		Force_for_old = Foldername + ":" + Forcename + "F" + num2str(i)
		if (Waveexists($Force_for_old) == 1)
			Force_back_old = Foldername + ":" + Forcename + "B" + num2str(i)
			Ext_for_old = Foldername + ":" + Lengthname + "F" + num2str(i)
			Ext_back_old = Foldername + ":" + Lengthname + "B" + num2str(i)
			k = start + counter
			Force_for_new = "root:Data:" + Forcename + "F" + num2str(k)
			Force_back_new = "root:Data:" + Forcename + "B" + num2str(k)
			Ext_for_new = "root:Data:" + Lengthname + "F" + num2str(k)
			Ext_back_new = "root:Data:" + Lengthname + "B" + num2str(k)

			Duplicate $Force_for_old, $Force_for_new
			Duplicate $Force_back_old, $Force_back_new
			Duplicate $Ext_for_old, $Ext_for_new
			Duplicate $Ext_back_old, $Ext_back_new
			counter += 1
		endif
	endfor
	Notebook NotebookOrigin text="Waves " + num2str(start) + " to " + num2str(k) + " from " + Foldername + "\r"
	SetDataFolder root:Data

End

//********************************************************************************************************************************
// This shifts the extension either by a constant value if only Cursor A is on graph or by a straight line if 
// Cursors A and B are on graph
Function FX_Baseline(ctrlName) : ButtonControl
	String ctrlName
	Variable cursorA, cursorB=-1
	String forcename
	SetDataFolder root:Data
	forcename = CsrWave(A, "ForceExtensionAnalysis")
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0)
		DoAlert 0, "Place cursor A or cursor A and B on trace"
		return 0
	endif
	cursorA = pcsr(A, "ForceExtensionAnalysis")
	if (strlen(CsrInfo(B, "ForceExtensionAnalysis")) > 0)
		cursorB = pcsr(B, "ForceExtensionAnalysis")
		DoAlert 1, "Adjust force by a fit between cursors A and B?"
		if (V_Flag == 2)
			return 0
		endif
	else
		DoAlert 1, "Adjust force by the constant value at cursor A?"
		if (V_Flag == 2)
			return 0
		endif
	endif
	if (cursorB < 0)	// constant value
		WaveStats/Q/R=[cursorA, cursorA+100] $forcename
		Duplicate/O $forcename, temp
		temp -= V_avg
		Duplicate/O temp, $forcename
	else			// fit line between A and B
		CurveFit/Q line, $forcename[cursorA, cursorB]
		Wave W_coef
		Duplicate/O $forcename, temp
		temp -= (W_coef[0] + W_coef[1] * x)
		Duplicate/O temp, $forcename
	endif
	KillWaves/Z temp, W_coef, W_sigma
End

//********************************************************************************************************************************
Function FX_SetElasticityModel(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL=root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR D = root:FX_Analysis:Fits:Variables:ChainThickness
	NVAR a = root:FX_Analysis:Fits:Variables:DiscSeparation
	NVAR n = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	String Force_B
	Variable i=0
	Make/O/T/N=7 ModelNames={"WLC", "WLCSe", "FJC", "FJCSe", "FRC", "FRCSe", "TC"}
	Model = popNum-1	
	FX_ModelDisplay()
	L = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_L")]
	if ( L > 0 )
		Force_B="Force_B"+num2str(DisplayNo)
		do			// generate fit for each peak i
			Cursor/P/W=ForceExtensionAnalysis A $Force_B FitParam[DisplayNo][0][%CursorA]
			Cursor/P/W=ForceExtensionAnalysis B $Force_B FitParam[DisplayNo][0][%CursorB]
			if ( Model == 2 || Model == 3)		
				p = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_Kuhn")]
			else
				p = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_p")]
			endif
			L = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_L")]
			DeltaL = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_Delta")]
			n = FitParam[DisplayNo][0][%nCurves]
			if ( Model == 1 || Model == 3 || Model == 5 )
				Se = FitParam[DisplayNo][0][%$(ModelNames[Model]+"_Se")]
			endif
			if ( Model == 4 || Model == 5 )
				Angle = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_Angle")]
				c = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_c")]
				//b = FitParam[DisplayNo][i][%$(ModelNames[Model]+"_b")]
			endif
			if ( Model == 6 )
				D = FitParam[DisplayNo][i][%TC_Thick]
				a = FitParam[DisplayNo][i][%TC_Sep]
			endif
			if (fitmode == 0)
				if ( Model == 0 )		// now that we finished loading all values, call appropriate functions to create fits
					FX_DisplayWLC()
				elseif ( Model == 1 )
					FX_DisplayWLCSe()
				elseif ( Model == 2 )
					FX_DisplayFJC()
				elseif ( Model == 3 )
					FX_DisplayFJCSe()
				elseif ( Model == 4 )
					FX_DisplayLidavaru()
				elseif ( Model == 5 )
					FX_DisplayLidavaruSe()
				elseif ( Model == 6 )
					FX_DisplayTC()
				endif
				return 0
			else
				if ( Model == 0 )		// now that we finished loading all values, call appropriate functions to create fits
					FX_DisplayEachWLC()
				elseif ( Model == 1 )		
					FX_DisplayEachWLCSe()
				elseif ( Model == 2 )		
					FX_DisplayEachFJC()
				elseif ( Model == 3 )		
					FX_DisplayEachFJCSe()
				elseif ( Model == 4 )		
					FX_DisplayEachLidavaru()
				elseif ( Model == 5 )	
					FX_DisplayEachLidavaruSe()
				elseif ( Model == 6 )
					FX_DisplayEachTC()
				endif
				i += 1
			endif
		while ( FitParam[DisplayNo][i][%$(ModelNames[Model]+"_L")] > 0 )
	else
		p = 0.4
		L = 100
		DeltaL = 24
		Se = 10000
		Angle = 40
		c = 1
		D = 0.25
		a = 0.38
		for (i=0; i<40; i+=1)								//remove old waves
		//	waveY="Y"+num2str(i)
			RemoveFromGraph/Z/W=ForceExtensionAnalysis $("Y"+num2str(i))
		endfor
		return 0
	endif	
End

//********************************************************************************************************************************
// This function in called by Display_FX_Recordings and loads the values that were used for the last fit into the Analysis panel.
// It also calls the appropriate model functions to display the elasticity model fits.
Function FX_LoadParameters()
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL=root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR D = root:FX_Analysis:Fits:Variables:ChainThickness
	NVAR a = root:FX_Analysis:Fits:Variables:DiscSeparation
	NVAR n = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	Variable i=0
	Make/O/T/N=7 ModelNames={"WLC", "WLC with Se", "FJC", "FJC with Se", "FRC/EJC", "FRC with Se", "TC"}
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	if ( FitParam[DisplayNo][0][%Model] >= 0 )		// if wave has been fit before, load old parameters
		Model = FitParam[DisplayNo][0][%Model]
		DoWindow/F Analysispanel
		PopupMenu popupFXModel,mode=Model+1
		FX_SetElasticityModel("",Model+1,"") 
	else
		p = 0.4
		L = 100
		DeltaL = 24
		Se = 10000
		Angle = 40
		c = 1
		D = 0.25
		a = 0.38
		return 0
	endif
End

//********************************************************************************************************************************
Function FX_ModelDisplay()
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	DoWindow/F Analysispanel
	SetVariable setvarFXp, title="p (nm)"
	SetVariable setvarFXAngle, disable= 1	
	Slider sliderFXAngle, disable=1	
	SetVariable setvarFXc, disable=1
	SetVariable setvarFXThick, disable= 1
	Slider sliderFXThick, disable= 1
	SetVariable setvarFXSep, disable= 1
	Slider sliderFXSep, disable= 1
	if (Model == 0)	// WLC
		PopupMenu popupFXFit, disable= 0, value= #"\"none;A;A to B\""			
		if(f==0)
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 0
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 0			
		elseif(f==1)
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 2
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 2
		elseif(f==2)
			Slider sliderFXP, disable= 2
			Slider sliderFXL, disable= 2
			SetVariable setvarFXp, disable= 2
			SetVariable setvarFXL, disable= 2
		endif
		SetVariable setvarSe, disable= 1
		Slider sliderFXSe, disable= 1
	else	
		if (f==0)
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 0
			Slider sliderFXSe, disable= 0
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 0	
			SetVariable setvarSe, disable=0
		elseif (f==1)
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 2
			Slider sliderFXSe, disable= 0
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 2
			SetVariable setvarSe, disable=0
		elseif (f==2)
			Slider sliderFXP, disable= 2
			Slider sliderFXL, disable= 2
			Slider sliderFXSe, disable= 2
			SetVariable setvarFXp, disable= 2
			SetVariable setvarFXL, disable= 2
			SetVariable setvarSe, disable=2
		endif
		PopupMenu popupFXFit, disable= 0, value= #"\"none;A\""	
		SetVariable setvarSe, disable= 0,  title="Se (pN)"
		Slider sliderFXSe, disable= 0
		if (Model == 1)	// WLC with SE	
		elseif (Model == 2)	// FJC
			PopupMenu popupFXFit, disable= 0, value= #"\"none;A; A to B\""	
			SetVariable setvarFXp, title="Kuhn (nm)"
			SetVariable setvarSe, disable= 1
			Slider sliderFXSe, disable= 1
		elseif (Model == 3)	// FJC with Se
			PopupMenu popupFXFit, disable= 0, value= #"\"none;A\""	
			SetVariable setvarFXp, title="Kuhn (nm)"
			SetVariable setvarSe, title="Se (pN/nm)"
		elseif (Model == 4)	//Lidavaru
			SetVariable setvarFXp, disable=2
			SetVariable setvarFXAngle, disable= 0	
			Slider sliderFXP, disable= 1
			Slider sliderFXAngle, disable=0
			SetVariable setvarFXc, disable=0
			SetVariable setvarSe, disable= 1
			Slider sliderFXSe, disable= 1
		elseif (Model == 5)	//Lidavaru with Se
			SetVariable setvarFXp, disable=2
			SetVariable setvarFXAngle, disable= 0	
			Slider sliderFXP, disable= 1
			Slider sliderFXAngle, disable=0
			SetVariable setvarFXc, disable=0
		elseif (Model == 6)	//TC
			SetVariable setvarFXp, disable= 2
			Slider sliderFXP, disable= 1
			SetVariable setvarSe, disable= 1
			Slider sliderFXSe, disable= 1
			SetVariable setvarFXThick, disable= 0
			Slider sliderFXThick, disable= 0
			SetVariable setvarFXSep, disable= 0
			Slider sliderFXSep, disable= 0
		endif
	endif
End

//********************************************************************************************************************************
Function FX_UpdateFits(ctrlName) : ButtonControl
	String ctrlName
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	SetDataFolder root:Data
	if (Model == 0)
		if (f==0)
			Slider sliderFXP, disable=0
			SetVariable setvarFXp, disable=0
			Slider sliderFXL, disable=0
			SetVariable setvarFXL, disable=0		
		elseif (f==1)
			FitWLCToCursor()
			Slider sliderFXP, disable=0
			SetVariable setvarFXp, disable=0
			Slider sliderFXL, disable=2
			SetVariable setvarFXL, disable=2				
		elseif (f==2)
			FitWLCToAandB()
			Slider sliderFXP, disable=2
			SetVariable setvarFXp, disable=2
			Slider sliderFXL, disable=2
			SetVariable setvarFXL, disable=2
		endif
		if (fitmode == 0)
			FX_DisplayWLC()
		else
			FX_DisplayEachWLC()
		endif
	elseif (Model ==1)	// WLC with Se
		Slider sliderFXP, disable= 0
		Slider sliderFXSe, disable= 0
		SetVariable setvarFXp, disable= 0
		SetVariable setvarSe, disable=0	
		if (f==0)
			Slider sliderFXL, disable= 0
			SetVariable setvarFXL, disable= 0	
		elseif (f==1)
			FitWLCSeToCursor()
			Slider sliderFXL, disable= 2
			SetVariable setvarFXL, disable= 2
		endif
		if (fitmode == 0)
			FX_DisplayWLCSe()
		else
			FX_DisplayEachWLCSe()
		endif
	elseif (Model ==2)	// FJC 
		Slider sliderFXSe, disable= 1
		SetVariable setvarSe, disable=1	
		if (f==0)
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 0		
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 0			
		elseif (f==1)
			FitFJCToCursor()
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 2
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 2	
		elseif (f==2)
			FitFJCToAandB()
			Slider sliderFXP, disable= 2
			Slider sliderFXL, disable= 2
			SetVariable setvarFXp, disable= 2
			SetVariable setvarFXL, disable= 2
		endif
		if (fitmode == 0)
			FX_DisplayFJC()
		else
			FX_DisplayEachFJC()
		endif
	elseif (Model ==3)	// FJC with Se
		if (f==0)
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 0
			Slider sliderFXSe, disable= 0
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 0	
			SetVariable setvarSe, disable=0	
		elseif (f==1)
			FitFJCSeToCursor()
			Slider sliderFXP, disable= 0
			Slider sliderFXL, disable= 2
			Slider sliderFXSe, disable= 0
			SetVariable setvarFXp, disable= 0
			SetVariable setvarFXL, disable= 2
			SetVariable setvarSe, disable=0	
		elseif (f==2)
			FitFJCSeToAandB()
			Slider sliderFXP, disable= 2
			Slider sliderFXL, disable= 2
			Slider sliderFXSe, disable= 2
			SetVariable setvarFXp, disable= 2
			SetVariable setvarFXL, disable= 2
			SetVariable setvarSe, disable=2
		endif
		if (fitmode == 0)
			FX_DisplayFJCSe()
		else
			FX_DisplayEachFJCSe()
		endif
	elseif (Model ==4)	//FRC/EJC
		Slider sliderFXSe, disable= 1
		SetVariable setvarSe, disable=1	
		if (f==0)
			Slider sliderFXL, disable=0
			SetVariable setvarFXL, disable=0		
		elseif (f==1)
			FitFRCToCursor()
			Slider sliderFXL, disable=2
			SetVariable setvarFXL, disable=2		
		endif
		if (fitmode == 0)
			FX_DisplayLidavaru()
		else
			FX_DisplayEachLidavaru()
		endif
	elseif (Model ==5)	//FRC/EJC with Se
		if (f==0)
			Slider sliderFXL, disable=0
			SetVariable setvarFXL, disable=0		
		elseif (f==1)
			FitFRCSeToCursor()
			Slider sliderFXL, disable=2
			SetVariable setvarFXL, disable=2		
		endif
		if (fitmode == 0)
			FX_DisplayLidavaruSe()
		else
			FX_DisplayEachLidavaruSe()
		endif
	elseif (Model ==6)	//TC
		if (f==0)
			Slider sliderFXL, disable=0
			SetVariable setvarFXL, disable=0		
		elseif (f==1)
			FitTCToCursor()
			Slider sliderFXL, disable=2
			SetVariable setvarFXL, disable=2		
		endif
		if (fitmode == 0)
			FX_DisplayTC()
		else
			FX_DisplayEachTC()
		endif		
	endif
End

//********************************************************************************************************************************
Function FX_CallUpdate(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	FX_UpdateFits(" ")
End

//********************************************************************************************************************************
Function FX_CheckTag(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	NVAR t=root:FX_Analysis:Fits:Tags
	t=checked
	FX_UpdateFits(" ")
End


//********************************************************************************************************************************
Function SetP(name, value, event)			// slider sets p
	String name
	Variable value, event
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	if (Model == 0)
		if (f==1)
			FitWLCToCursor()
		 endif
		 if (fitmode == 0)
			FX_DisplayWLC()
		else
			FX_DisplayEachWLC()
		endif
	elseif (Model ==1)	// WLC with Se
		if (f==1)
			FitWLCSeToCursor()
		 endif
		if (fitmode == 0)
			FX_DisplayWLCSe()
		else
			FX_DisplayEachWLCSe()
		endif
	elseif (Model ==2)	// FJC 
		if (f==1)
			FitFJCToCursor()
		 endif
		 if (fitmode == 0)
			FX_DisplayFJC()
		else
			FX_DisplayEachFJC()
		endif
	elseif (Model ==3)	// FJC with Se
		if (f==1)
			FitFJCSeToCursor()
		 endif
		 if (fitmode == 0)
			FX_DisplayFJCSe()
		else
			FX_DisplayEachFJCSe()
		endif
	endif
	DoUpdate
End

//********************************************************************************************************************************
Function SetL(name, value, event)			// slider sets L
	String name
	Variable value, event 
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	if (Model == 0)
		if (fitmode == 0)
			FX_DisplayWLC()
		else
			FX_DisplayEachWLC()
		endif
	elseif (Model ==1)	// WLC with Se
		if (fitmode == 0)
			FX_DisplayWLCSe()
		else
			FX_DisplayEachWLCSe()
		endif
	elseif (Model ==2)	// FJC 
		if (fitmode == 0)
			FX_DisplayFJC()
		else
			FX_DisplayEachFJC()
		endif
	elseif (Model ==3)	// FJC with Se
		 if (fitmode == 0)
			FX_DisplayFJCSe()
		else
			FX_DisplayEachFJCSe()
		endif
	elseif (Model ==4)	// FRC/EJC
		 if (fitmode == 0)
			FX_DisplayLidavaru()
		else
			FX_DisplayEachLidavaru()
		endif
	elseif (Model ==5)	// FRC/EJC with Se
		 if (fitmode == 0)
			FX_DisplayLidavaruSe()
		else
			FX_DisplayEachLidavaruSe()
		endif
	elseif (Model ==6)	// TC
		 if (fitmode == 0)
			FX_DisplayTC()
		else
			FX_DisplayEachTC()
		endif
	endif
	DoUpdate	
End

//********************************************************************************************************************************
Function SetSe(name, value, event)			// slider sets Se
	String name
	Variable value, event 
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	if (Model ==1)		// WLC with Se
		if (f==1)
			FitWLCSeToCursor()
		 endif
		if (fitmode == 0)
			FX_DisplayWLCSe()
		else
			FX_DisplayEachWLCSe()
		endif
	elseif (Model ==3)	// FJC with Se 
		if (f==1)
			FitFJCSeToCursor()
		 endif
		if (fitmode == 0)
			FX_DisplayFJCSe()
		else
			FX_DisplayEachFJCSe()
		endif
	elseif (Model ==5)	// FRC/EJC with Se
		if (f==1)
			FitFRCSeToCursor()
		 endif
		if (fitmode == 0)
			FX_DisplayLidavaruSe()
		else
			FX_DisplayEachLidavaruSe()
		endif
	endif
	DoUpdate	
End

//********************************************************************************************************************************
Function SetAngle(name, value, event)			// slider sets L
	String name
	Variable value, event 
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	if (Model ==4)	// FRC/EJC
		if (f==1)
			FitFRCToCursor()
		 endif
		if (fitmode == 0)
			FX_DisplayLidavaru()
		else
			FX_DisplayEachLidavaru()
		endif
	elseif (Model ==5)	// FRC/EJC with Se
		if (f==1)
			FitFRCSeToCursor()
		 endif
		if (fitmode == 0)
			FX_DisplayLidavaruSe()
		else
			FX_DisplayEachLidavaruSe()
		endif
	endif
	DoUpdate	
End

//********************************************************************************************************************************
Function SetThickness(name, value, event)			// slider sets L
	String name
	Variable value, event 
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	if (Model ==6)	// TC
		if (f==1)
			FitTCToCursor()
		 endif
		 if (fitmode == 0)
			FX_DisplayTC()
		else
			FX_DisplayEachTC()
		endif
	endif
	DoUpdate	
End

//********************************************************************************************************************************
Function SetSeparation(name, value, event)			// slider sets L
	String name
	Variable value, event 
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	NVAR fitmode = root:FX_Analysis:Fits:Separate
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	if (Model ==6)	// TC
		if (f==1)
			FitTCToCursor()
		 endif
		 if (fitmode == 0)
			FX_DisplayTC()
		else
			FX_DisplayEachTC()
		endif
	endif
	DoUpdate	
End
//********************************************************************************************************************************
Function FX_SelectFit(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	NVAR f=root:FX_Analysis:Fits:SetLtoCursor
	f=popNum-1	
	FX_UpdateFits(" ")
End

//********************************************************************************************************************************
Function FitWLCToCursor()		//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=10000 WLC, LC	
	xvalue = hcsr(A, "ForceExtensionAnalysis")	
	Fvalue = vcsr(A, "ForceExtensionAnalysis")		
	SetScale/I x  xvalue+5, xvalue+100, WLC
	SetScale/I x  xvalue+5, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is
	WLC = kT / p * ( xvalue/LC + 0.25 / (1-xvalue/LC)^2 - 0.25)		// gives WLC for a range of LCs at a specific length x
	FindLevel/Q WLC, Fvalue
	L = V_LevelX
//	KillWaves/Z WLC, LC
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FitWLCSeToCursor()		//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=20000 WLC, LC	
	xvalue = hcsr(A, "ForceExtensionAnalysis")	
	Fvalue = vcsr(A, "ForceExtensionAnalysis")		
	SetScale/I x  xvalue-100, xvalue+100, WLC
	SetScale/I x  xvalue-100, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is	
	
	WLC = kT / p * ( xvalue/LC - Fvalue/Se + 0.25 / (1-xvalue/LC+Fvalue/Se)^2 - 0.25)		// gives WLC for a range of LCs at a specific length x
	FindLevel/Q/P/R=[numpnts(WLC)-1,0] WLC, Fvalue		// find which LC works best
	L = LC[V_LevelX]
//	KillWaves/Z WLC, LC
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FitFJCToCursor()			//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR Kuhn=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=12000 FJC, LC
	xvalue = hcsr(A, "ForceExtensionAnalysis")		
	Fvalue = vcsr(A, "ForceExtensionAnalysis")	
	SetScale/I x  xvalue-20, xvalue+100, FJC
	SetScale/I x  xvalue-20, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is			
	FJC = ( 1/tanh(Fvalue*Kuhn/kT) - kT/Fvalue/Kuhn ) * LC	// gives FJC for a range of LCs at a specific Force
	FindLevel/Q FJC, xvalue	// find which LC works best
	L = V_LevelX		
	KillWaves/Z FJC, LC
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FitFJCSeToCursor()		//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR Kuhn=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=12000 FJC, LC
	xvalue = hcsr(A, "ForceExtensionAnalysis")		
	Fvalue = vcsr(A, "ForceExtensionAnalysis")	
	SetScale/I x  xvalue-20, xvalue+100, FJC
	SetScale/I x  xvalue-20, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is			
	FJC = ( 1/tanh(Fvalue*Kuhn/kT) - kT/Fvalue/Kuhn ) * LC * (1 + Fvalue/Kuhn/Se )	// gives FJC for a range of LCs at a specific Force
	FindLevel/Q FJC, xvalue	// find which LC works best
	L = V_LevelX		
	KillWaves/Z FJC, LC
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FitFRCToCursor()			//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue, b=0.154, radians, pb, yW, realW, imagW, W, Inverse, zet, beta=2
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=20000 FRC, LC	
	xvalue = hcsr(A, "ForceExtensionAnalysis")	
	Fvalue = vcsr(A, "ForceExtensionAnalysis")		
	SetScale/I x  xvalue-100, xvalue+100, FRC
	SetScale/I x  xvalue-100, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is
			
	radians = Angle/360 * 2 * Pi	//convert from degree to radians
	pb = cos(radians/2) / abs(ln(cos(radians)))
	yW = Fvalue * b / kT		// force * b / kT	
	realW = real ((2 + (4 + (1 - 4/3 * yW * pb )^3 )^(1/2) )^(1/3))	// real part
	imagW = imag((2 + (4 + (1 - 4/3 * yW * pb)^3 )^(1/2) )^(1/3))	// imaginary part
	W = sqrt (realW^2 + imagW^2)								
	Inverse = (4/3 * yW * pb - 1) / W + W
	zet = 1- ( Inverse ^beta + (c * yW)^beta ) ^ (-1/beta)	// z/L
	FRC = zet * LC		
	
	FindLevel/Q/P/R=[numpnts(FRC)-1,0] FRC, xvalue		// find which LC works best
	L = LC[V_LevelX]
	KillWaves/Z WLC, LC
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FitFRCSeToCursor()			//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR GammaTilda = root:FX_Analysis:Fits:Variables:SegmentElasticity	
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue, b=0.154, radians, pb, yW, realW, imagW, W, Inverse, zet, beta=2
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=20000 FRC, LC
	xvalue = hcsr(A, "ForceExtensionAnalysis")	
	Fvalue = vcsr(A, "ForceExtensionAnalysis")		
	SetScale/I x  xvalue-100, xvalue+100, FRC
	SetScale/I x  xvalue-100, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is
			
	radians = Angle/360 * 2 * Pi	//convert from degree to radians
	pb = cos(radians/2) / abs(ln(cos(radians)))
	yW = Fvalue * b / kT		// force * b / kT	
	realW = real ((2 + (4 + (1 - 4/3 * yW * pb )^3 )^(1/2) )^(1/3))	// real part
	imagW = imag((2 + (4 + (1 - 4/3 * yW * pb)^3 )^(1/2) )^(1/3))	// imaginary part
	W = sqrt (realW^2 + imagW^2)								
	Inverse = (4/3 * yW * pb - 1) / W + W
	zet = 1- ( Inverse ^beta + (c * yW)^beta ) ^ (-1/beta) + Fvalue/GammaTilda	// z/L
	FRC = zet * LC		
	
	FindLevel/Q/P/R=[numpnts(FRC)-1,0] FRC, xvalue		// find which LC works best
	L = LC[V_LevelX]
	KillWaves/Z WLC, LC
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FitTCToCursor()			//fit the first trace to cursor(A) returns appropriate value for L in the globals
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR D = root:FX_Analysis:Fits:Variables:ChainThickness
	NVAR a = root:FX_Analysis:Fits:Variables:DiscSeparation
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable xvalue, Fvalue
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0 )
		DoAlert 0, "Place cursor A on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis
	Make/O/N=10000 TC, LC
	k1 = -0.28394 + 0.76441 * D/a + 0.31858 * (D/a)^2
	k2 =  0.15989 -  0.50503 * D/a -  0.20636 * (D/a)^2
	k3 = -0.34984 + 1.23330 * D/a + 0.58697 * (D/a)^2	
	xvalue = hcsr(A, "ForceExtensionAnalysis")	
	Fvalue = vcsr(A, "ForceExtensionAnalysis")		
	SetScale/I x  xvalue+5, xvalue+100, TC
	SetScale/I x  xvalue+5, xvalue+100, LC	
	LC = x		// generate a wave of Contourlengths starting just above where cursor is
	TC = kT/a/(1-xvalue/LC)* tanh ((k1*(xvalue/LC)^(3/2) + k2*(xvalue/LC)^2 + k3*(xvalue/LC)^3)/(1-xvalue/LC))		// gives WLC for a range of LCs at a specific length x
	FindLevel/Q TC, Fvalue
	L = V_LevelX
	KillWaves/Z TC, LC
	SetDataFolder root:Data			
End

//********************************************************************************************************************************
Function FitWLCToAandB()
	NVAR p=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Chisq = root:FX_Analysis:Fits:Variables:chisq
	Wave RefWave = CsrWaveRef(A, "ForceExtensionAnalysis")
	Wave CurrentWave = CsrXWaveRef(A, "ForceExtensionAnalysis")
	Variable pA, pB
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0  ||  strlen(CsrInfo(B, "ForceExtensionAnalysis")) == 0)
		DoAlert 0, "Place cursors A and B on trace!"
		return 0
	endif
	pA = pcsr(A, "ForceExtensionAnalysis")
	pB = pcsr(B, "ForceExtensionAnalysis")
	Make/D/N=2/O W_coef
	W_coef[0] = {0.3, hcsr(B, "ForceExtensionAnalysis")+50}
	FuncFit/N/Q LVFitWLC W_coef RefWave[pA,pB] /X=CurrentWave
	p=W_coef[0]
	L=W_coef[1]
	Chisq=V_chisq
	KillWaves/Z W_coef
End

//********************************************************************************************************************************
Function FitFJCToAandB()
	NVAR Kuhn=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Chisq = root:FX_Analysis:Fits:Variables:chisq
	Variable sm
	Wave CurrentWave = CsrXWaveRef(A, "ForceExtensionAnalysis")
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0  ||  strlen(CsrInfo(B, "ForceExtensionAnalysis")) == 0)
		DoAlert 0, "Place cursors A and B on trace!"
		return 0
	endif
	Make/D/N=2/O W_coef
	W_coef[0] = {0.3, hcsr(B, "ForceExtensionAnalysis")+50}	
	Duplicate/O/R=[pcsr(A, "ForceExtensionAnalysis"), pcsr(B, "ForceExtensionAnalysis")] CsrXWaveRef(A), length
	Duplicate/O/R=[pcsr(A, "ForceExtensionAnalysis"), pcsr(B, "ForceExtensionAnalysis")] CsrWaveRef(A), force
	sm = round(numpnts(force)/20) * 2 + 1		//odd
	Smooth/B sm, force
	FuncFit/N/Q LVFitFJC W_coef length /X=force /D
	Kuhn = W_coef[0]
	L = W_coef[1]
	Chisq=V_chisq
//	KillWaves/Z W_coef, length, force
End

//********************************************************************************************************************************
Function FitFJCSeToAandB()
	NVAR Kuhn=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR Chisq = root:FX_Analysis:Fits:Variables:chisq
	Variable sm
	Wave CurrentWave = CsrXWaveRef(A, "ForceExtensionAnalysis")
	if (strlen(CsrInfo(A, "ForceExtensionAnalysis")) == 0  ||  strlen(CsrInfo(B, "ForceExtensionAnalysis")) == 0)
		DoAlert 0, "Place cursors A and B on trace!"
		return 0
	endif
	SetDataFolder root:FX_Analysis:Fits
	Make/D/N=3/O W_coef
	W_coef[0] = {0.3, hcsr(B, "ForceExtensionAnalysis")+50, 20000}
	Duplicate/O/R=[pcsr(A, "ForceExtensionAnalysis"), pcsr(B, "ForceExtensionAnalysis")] CurrentWave, length
	Duplicate/O/R=[pcsr(A, "ForceExtensionAnalysis"), pcsr(B, "ForceExtensionAnalysis")] CurrentWave, force
	sm = round(numpnts(force)/20) * 2 + 1		//odd
	Smooth/B sm, force
	FuncFit/N/Q LVFitFJCSe W_coef length /X=force /D
	Kuhn = W_coef[0]
	L = W_coef[1]
	Se = W_coef[2]
	Chisq=V_chisq
//	KillWaves/Z W_coef, length, force
End

//********************************************************************************************************************************
Function FX_DisplayWLC()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR p = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR n = root:FX_Analysis:Fits:Variables:NumberOfCurves	
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Chisq = root:FX_Analysis:Fits:Variables:chisq
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable LC, i,  XOffset, YOffset
	String waveY, waveX, Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")							//wave reference to cursor A
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		
	
	for (i = 0; i < 20; i += 1)			//remove old waves					
		RemoveFromGraph/Z/W=ForceExtensionAnalysis $"Y"+num2str(i)
	endfor	
	FitParam[DisplayNo][0,19][%WLC_p,%WLC_Delta] = -1	//clear fields in parameter wave
	Duplicate/O CsrXWaveRef(A, "ForceExtensionAnalysis"), length
	Duplicate/O CsrWaveRef(A, "ForceExtensionAnalysis"), force
	for (i = 0; i < n; i += 1)			//create n curves
		LC = L - DeltaL*i			//contourlength								
		waveY = "Y"+num2str(i)
		waveX = "X"+num2str(i)
		force = (kT/p)*((0.25*(1.00-length/LC)^-2.00)-0.25+length/LC)	//  Evaluate WLC with the exact x values of the record
		FindLevel/P/Q force, 400
		force += YOffset
		length += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] length, $waveX
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
 	endfor
 	Tag/W=ForceExtensionAnalysis/K/N=Tag1
	if (t == 1)
 		Taginfo ="p = "+num2str(p)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)+" nm"
 		if (f == 2)
 			Taginfo += "\rChisq = "+num2str(Chisq)
 		endif
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-20/Y=10 $("Y0"), 10, Taginfo 					
 	endif	
 	FitParam[DisplayNo][0,n-1][%WLC_p] = p
 	FitParam[DisplayNo][0,n-1][%WLC_L] = L
 	FitParam[DisplayNo][0,n-2][%WLC_Delta] = DeltaL
 	if (n == 1)
 		FitParam[DisplayNo][0][%WLC_Delta] = -1
 	endif
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = n
 	FitParam[DisplayNo][0,n-1][%Model] = 0
	SetDataFolder root:Data
	KillWaves/Z force length
End

//********************************************************************************************************************************
Function FX_DisplayWLCSe()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR n = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR t = root:FX_Analysis:Fits:Tags	
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, j, RHS, LC, XOffset, YOffset
	String waveX, waveY, Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=200 force, length, LHS, testlength
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))
	Force = 2.5*p	// force goes from 0 to 500 pN
	testlength = 2.5*p
	
	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/Z/W=ForceExtensionAnalysis $"Y"+num2str(i)
	endfor
	FitParam[DisplayNo][0,19][%WLCSe_p,%WLC_Se] = -1	//clear fields in parameter wave
	for (i=0; i<n; i+=1)							//creates numberofcurves fits
		waveY="Y"+num2str(i)
		wavex="X"+num2str(i)
		LC=L - DeltaL*i
		j=0		
		do		//this is the loop to fill up the WLC fit wave
			//We will be filling up, in stepwise manner, a wave with extension values following the WLC+Se equation
			//F*p/kT = length/L - F/Se + 0.25/(1-length/L+F/Se)^2-0.25
			RHS = pL/kT * force[j]		
			LHS = testlength/LC - force[j]/Se + 0.25/(1-testlength/LC+force[j]/Se)^2 - 0.25
			FindLevel/P/Q LHS, RHS		// find where LHS corresponds to RHS
			if (V_flag == 1)
			//	print "No Levels found"
				break
			elseif (V_flag == 0)
				length[j] = testlength[V_LevelX]
			endif
			j += 1	
		while (j < numpnts(LHS))		
		FindLevel/P/Q force, 400
		force += YOffset
		length += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] length, $waveX
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
 	endfor		
 	if (t == 1)
		Tag/W=ForceExtensionAnalysis/K/N=Tag1
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rS\Be\M = "+num2str(Se) +" pN"
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-10/Y=60 $("Y0"), 10, Taginfo 					
 	endif	
 	FitParam[DisplayNo][0,n-1][%WLCSe_p] = pL
 	FitParam[DisplayNo][0,n-1][%WLCSe_L] = L
 	FitParam[DisplayNo][0,n-2][%WLCSe_Delta] = DeltaL
 	if (n == 1)
 		FitParam[DisplayNo][0][%WLCSe_Delta] = -1
 	endif
 	FitParam[DisplayNo][0,n-1][%WLCSe_Se] = Se
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = n
 	FitParam[DisplayNo][0,n-1][%Model] = 1
 	KillWaves/Z force, length, LHS, testlength			 		
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayFJC()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR Kuhn = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR n = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR Chisq=root:FX_Analysis:Fits:Variables:chisq
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, LC, XOffset, YOffset
	String waveX, waveY, Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 force, length, Arg, numofsegs	
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))
	Force = p
	
	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/Z/W=ForceExtensionAnalysis $("Y"+num2str(i))
	endfor
	FitParam[DisplayNo][0,19][%FJC_Kuhn,%FJC_Delta] = -1	//clear fields in parameter wave
	for (i=0; i<n; i+=1)							//creates numberofcurves fits
		waveY="Y"+num2str(i)
		wavex="X"+num2str(i)
		LC=L - DeltaL*i
			//x=((1/tanh(kuhn/kT*Force))-(kT/(Kuhn*Force)) * (ContourLength + (Force*(numofsegments/segmentelasticity)))
		Arg = Kuhn/kT * force
		numofsegs = LC/Kuhn			
		length = ((1/tanh(Arg))-(1/Arg))*LC	
		FindLevel/P/Q force, 400
		force += YOffset
		length += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] length, $waveX		
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
 	endfor
	Tag/W=ForceExtensionAnalysis/K/N=Tag1
	if (t == 1)
 		Taginfo ="Kuhn = "+num2str(Kuhn)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL) + " nm"
 		if (f == 2)
 			Taginfo += "\rChisq = "+num2str(Chisq)
 		endif
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-10/Y=60 $("Y0"), 10, Taginfo 					
 	endif			
 	FitParam[DisplayNo][0,n-1][%FJC_Kuhn] = Kuhn
 	FitParam[DisplayNo][0,n-1][%FJC_L] = L
 	FitParam[DisplayNo][0,n-2][%FJC_Delta] = DeltaL
 	if (n == 1)
 		FitParam[DisplayNo][0][%FJC_Delta] = -1
 	endif	
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = n
 	FitParam[DisplayNo][0,n-1][%Model] = 2
 	KillWaves/Z force, length, Arg, numofsegs
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayFJCSe()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR Kuhn=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL=root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR n = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR Chisq = root:FX_Analysis:Fits:Variables:chisq
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, LC, XOffset, YOffset
	String waveX, waveY, Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 force, length, Arg, numofsegs	
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))	
	Force = p

	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/Z/W=ForceExtensionAnalysis $("Y"+num2str(i))
	endfor
	FitParam[DisplayNo][0,19][%FJCSe_Kuhn, %FJCSe_Se] = -1	//clear fields in parameter wave
	for (i=0; i<n; i+=1)							//creates numberofcurves fits
		waveY="Y"+num2str(i)
		wavex="X"+num2str(i)
		LC=L - DeltaL*i
			//x=((1/tanh(kuhn/kT*Force))-(kT/(Kuhn*Force)) * (ContourLength + (Force*(numofsegments/segmentelasticity)))
		Arg = Kuhn/kT * force
		numofsegs = LC/Kuhn			
		length = ((1/tanh(Arg))-(1/Arg))*(LC + (force * (numofsegs/Se)))		
		FindLevel/P/Q force, 400
		force += YOffset
		length += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] length, $waveX		
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
 	endfor
	Tag/W=ForceExtensionAnalysis/K/N=Tag1
	if (t == 1)
 		Taginfo ="Kuhn = "+num2str(Kuhn)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rS\Be\M = "+num2str(Se) +" pN/nm"
 		if (f == 2)
 			Taginfo += "\rChisq = "+num2str(Chisq)
 		endif
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-10/Y=60 $("Y0"), 10, Taginfo 					
 	endif		
 	FitParam[DisplayNo][0,n-1][%FJCSe_Kuhn] = Kuhn
 	FitParam[DisplayNo][0,n-1][%FJCSe_L] = L
 	FitParam[DisplayNo][0,n-2][%FJCSe_Delta] = DeltaL
 	if (n == 1)
 		FitParam[DisplayNo][0][%FJCSe_Delta] = -1
 	endif
 	FitParam[DisplayNo][0,n-1][%FJCSe_Se] = Se		
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = n
 	FitParam[DisplayNo][0,n-1][%Model] = 3		
 	KillWaves/Z force, length, Arg, numofsegs
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayLidavaru()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR nCurves = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable radians, i, pb, LC, b=0.154, beta=2, XOffset, YOffset
	String waveX, waveY,Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, CurrentWave=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 Force, yW, realW, imagW, W, Inverse, zet, finalz
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))	
	b=0.154
	radians = Angle/360 * 2 * Pi	//convert from degree to radians
	pb = cos(radians/2) / abs(ln(cos(radians)))
	pL = b* pb
//	N = L / (b * cos(radians/2) )
//	Ftrans = 4 * kT * p/b^2	
	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/W=ForceExtensionAnalysis/Z $("Y"+num2str(i))
	endfor	
	FitParam[DisplayNo][0,19][%FRC_p,%FRC_b] = -1	//clear fields in parameter wave
	Force = p
	yW = Force * b / kT		// force * b / kT	
	realW =   real ((2 + (4 + (1 - 4/3 * yW * pb )^3 )^(1/2) )^(1/3))	// real part
	imagW = imag((2 + (4 + (1 - 4/3 * yW * pb)^3 )^(1/2) )^(1/3))	// imaginary part
	W = sqrt (realW^2 + imagW^2)								
	Inverse = (4/3 * yW * pb - 1) / W + W
	zet = 1- ( Inverse ^beta + (c * yW)^beta ) ^ (-1/beta) 
	
	for (i = 0; i < nCurves; i+= 1)
		LC=L - DeltaL*i
		waveY="Y"+num2str(i)
		wavex="X"+num2str(i)
		finalz = zet * LC		
		FindLevel/P/Q Force, 400
		Force += YOffset
		finalz += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] finalz, $waveX	
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
	endfor
	Tag/W=ForceExtensionAnalysis/K/N=Tag1
	if (t == 1)
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rBond Angle = "+num2str(Angle)+"°\rBondlength = "
 		Taginfo += num2str(b)+" nm\rc = "+num2str(c)
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-10/Y=60 $("Y0"), 40, Taginfo 					
 	endif
 	
 	FitParam[DisplayNo][0,nCurves-1][%FRC_p] = pL
 	FitParam[DisplayNo][0,nCurves-1][%FRC_L] = L
 	FitParam[DisplayNo][0,nCurves-2][%FRC_Delta] = DeltaL
 	if (nCurves == 1)
 		FitParam[DisplayNo][0][%FRC_Delta] = -1
 	endif
 	FitParam[DisplayNo][0,nCurves-1][%FRC_Angle] = Angle	
 	FitParam[DisplayNo][0,nCurves-1][%FRC_c] = c
 	FitParam[DisplayNo][0,nCurves-1][%FRC_b] = b	
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = nCurves
 	FitParam[DisplayNo][0,nCurves-1][%Model] = 4
	KillWaves/Z Force, yW, realW, imagW, W, Inverse, zet, finalz
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayLidavaruSe()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR nCurves = root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR GammaTilda = root:FX_Analysis:Fits:Variables:SegmentElasticity	
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable radians, i, pb, LC, b=0.154, beta=2, XOffset, YOffset
	String waveX, waveY, Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, CurrentWave=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 Force, yW, realW, imagW, W, Inverse, zet, finalz
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))	
	b=0.154
	radians = Angle/360 * 2 * Pi	//convert from degree to radians
	pb = cos(radians/2) / abs(ln(cos(radians)))
	pL = b* pb
//	N = L / (b * cos(radians/2) )
//	Ftrans = kT * p/b^2	
	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/W=ForceExtensionAnalysis/Z $("Y"+num2str(i))
	endfor	
	FitParam[DisplayNo][0,19][%FRCSe_p,%FRCSe_Se] = -1	//clear fields in parameter wave
	Force = p
	yW = Force * b / kT		// force * b / kT	
	realW =   real ((2 + (4 + (1 - 4/3 * yW * pb )^3 )^(1/2) )^(1/3))	// real part
	imagW = imag((2 + (4 + (1 - 4/3 * yW * pb)^3 )^(1/2) )^(1/3))	// imaginary part
	W = sqrt (realW^2 + imagW^2)								
	Inverse = (4/3 * yW * pb - 1) / W + W
	zet = 1- ( Inverse ^beta + (c * yW)^beta ) ^ (-1/beta) + Force/GammaTilda
	
	for (i = 0; i < nCurves; i+= 1)
		LC=L - DeltaL*i
		waveY="Y"+num2str(i)
		wavex="X"+num2str(i)
		finalz = zet * LC	
		FindLevel/P/Q Force, 400
		Force += YOffset
		finalz += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] finalz, $waveX			
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
	endfor
	Tag/W=ForceExtensionAnalysis/K/N=Tag1
	if (t == 1)
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rBond Angle = "+num2str(Angle)+"°\rS\Be\M = "+num2str(GammaTilda)+" pN/nm\rBondlength = "
 		Taginfo += num2str(b)+" nm\rc = "+num2str(c)
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-10/Y=60 $("Y0"), 40, Taginfo 					
 	endif	
 	
 	FitParam[DisplayNo][0,nCurves-1][%FRCSe_p] = pL
 	FitParam[DisplayNo][0,nCurves-1][%FRCSe_L] = L
 	FitParam[DisplayNo][0,nCurves-2][%FRCSe_Delta] = DeltaL
 	if (nCurves == 1)
 		FitParam[DisplayNo][0][%FRCSe_Delta] = -1
 	endif
 	FitParam[DisplayNo][0,nCurves-1][%FRCSe_Angle] = Angle	
 	FitParam[DisplayNo][0,nCurves-1][%FRCSe_c] = c
 	FitParam[DisplayNo][0,nCurves-1][%FRCSe_b] = b
 	FitParam[DisplayNo][0,nCurves-1][%FRCSe_Se] = GammaTilda	
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = nCurves
 	FitParam[DisplayNo][0,nCurves-1][%Model] = 5
	KillWaves/Z Force, yW, realW, imagW, W, Inverse, zet, finalz
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayTC()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL=root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR n=root:FX_Analysis:Fits:Variables:NumberOfCurves
	NVAR t=root:FX_Analysis:Fits:Tags
	NVAR D = root:FX_Analysis:Fits:Variables:ChainThickness
	NVAR a = root:FX_Analysis:Fits:Variables:DiscSeparation
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, LC, k1, k2, k3, XOffset, YOffset
	String waveX, waveY, Taginfo
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 force, length, finallength
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))	
	length = p/2000
	k1 = -0.28394 + 0.76441 * D/a + 0.31858 * (D/a)^2
	k2 =  0.15989 -  0.50503 * D/a -  0.20636 * (D/a)^2
	k3 = -0.34984 + 1.23330 * D/a + 0.58697 * (D/a)^2
	pL = -a / ln(1 - a^2/4/D^2)
	
	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/W=ForceExtensionAnalysis/Z $("Y"+num2str(i))
	endfor
	FitParam[DisplayNo][0,19][%TC_p,%TC_Sep] = -1	//clear fields in parameter wave
	for (i=0; i<n; i+=1)							//creates numberofcurves fits
		waveY="Y"+num2str(i)
		wavex="X"+num2str(i)
		LC=L - DeltaL*i
		//force = kT/a/(1-x)* tanh ((k1*x^(3/2) + k2*x^2 + k3*x^3)/(1-x))		
		force = kT/a/(1-length)* tanh ((k1*length^(3/2) + k2*length^2 + k3*(length)^3)/(1-length))			
		finallength = (length*LC)
		FindLevel/P/Q Force, 400
		Force += YOffset
		finallength += XOffset
		Duplicate/O/R=[0, V_LevelX] force, $waveY
		Duplicate/O/R=[0, V_LevelX] finallength, $waveX	
		AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
 	endfor
 	Tag/W=ForceExtensionAnalysis/K/N=Tag1
	if (t == 1)
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rChain Thickness = "+num2str(D)+" nm\rDisc Separation = "+num2str(a)+" nm"
 		Tag/W=ForceExtensionAnalysis/N=Tag1/F=2/X=-10/Y=60 $("Y0"), 400, Taginfo 					
 	endif
 	
 	FitParam[DisplayNo][0,n-1][%TC_p] = pL
 	FitParam[DisplayNo][0,n-1][%TC_L] = L
 	FitParam[DisplayNo][0,n-2][%TC_Delta] = DeltaL
 	if (n == 1)
 		FitParam[DisplayNo][0][%TC_Delta] = -1
 	endif
 	FitParam[DisplayNo][0,n-1][%TC_Thick] = D	
 	FitParam[DisplayNo][0,n-1][%TC_Sep] = a
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][0][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][0][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][0][%nCurves] = n
 	FitParam[DisplayNo][0,n-1][%Model] = 6
 	KillWaves/Z force, length
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_FitEachPeak(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked
	SetDataFolder root:FX_Analysis:Fits
	if (checked == 1)
		Doalert 0,"Obtain peak forces and locations from left to right IN ORDER before fitting with any elasticity model!"	
		DoWindow FitParam_Table
		if (V_Flag == 0)
			Edit/N=FitParam_Table FitParam.ld
		endif
		SetVariable setvarFXCurves, disable =1
		SetVariable setvarFXDelta, disable =2
	else
		SetVariable setvarFXCurves, disable =0
		SetVariable setvarFXDelta, disable =0
	endif	
End

//********************************************************************************************************************************
Function FX_ClearFits(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	Variable i
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	for (i=0; i<40; i+=1)								//remove old waves
		RemoveFromGraph/Z/W=ForceExtensionAnalysis $("Y"+num2str(i))
	endfor
	FitParam[DisplayNo][0,19][2,37] = -1
End

//********************************************************************************************************************************
Function FX_DisplayEachWLC()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR p = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength	
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Chisq=root:FX_Analysis:Fits:Variables:chisq
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i,  XOffset, YOffset, CursorA, PeakNumber
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")		//wave reference to cursor A
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		
	CursorA = pcsr(A, "ForceExtensionAnalysis")
	for (i = 20; i >= 0; i -= 1)
		if (CursorA < FitParam[DisplayNo][i][%PeakPointNumber])
			PeakNumber = i
		endif
	endfor	
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)				
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	
	
	Duplicate/O CsrXWaveRef(A, "ForceExtensionAnalysis"), length
	Duplicate/O CsrWaveRef(A, "ForceExtensionAnalysis"), force						
	force = (kT/p)*((0.25*(1.00-length/L)^-2.00)-0.25+length/L)	//  Evaluate WLC with the exact x values of the record
	FindLevel/P/Q force, 400
	force += YOffset
	length += XOffset
	Duplicate/O/R=[0, V_LevelX] force, $waveY
	Duplicate/O/R=[0, V_LevelX] length, $waveX
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
	// save all fit parameters in Table
 	FitParam[DisplayNo][PeakNumber][%WLC_p] = p
 	FitParam[DisplayNo][PeakNumber][%WLC_L] = L
 	 if ( FitParam[DisplayNo][PeakNumber+1][%WLC_L] > 0)		// dL to next peak
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%WLC_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%WLC_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%WLC_L] > 0) // dL to previous peak
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%WLC_L]
 		FitParam[DisplayNo][PeakNumber][%WLC_Delta] = DeltaL 
 	endif
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][%nCurves] = 1
 	FitParam[DisplayNo][PeakNumber][%Model] = 0
 	
 	Tagname = "Tag" + num2str(PeakNumber)
 	Tag/W=ForceExtensionAnalysis/K/N=Tagname
	if (t == 1)
 		Taginfo ="p = "+num2str(p)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)+" nm"
 		if (f == 2)
 			Taginfo += "\rChisq = "+num2str(Chisq)
 		endif
 		Tag/W=ForceExtensionAnalysis/N=$Tagname/F=2/X=-20/Y=10 $waveY, 10, Taginfo 					
 	endif	
	SetDataFolder root:Data
	KillWaves/Z force length
End

//********************************************************************************************************************************
Function FX_DisplayEachWLCSe()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100	
	Variable i, j, RHS, LC, XOffset, YOffset, PeakNumber, CursorA
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=200 force, length, LHS, testlength
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))	
	Force = 2.5*p	// force goes from 0 to 500 pN
	testlength = 2.5*p
	CursorA = pcsr(A, "ForceExtensionAnalysis")
	
	for (i = 20; i >= 0; i -= 1)	
		if (CursorA < FitParam[DisplayNo][i][0])
		PeakNumber = i		
		endif
	endfor
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)						
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	
	j=0		
	do		//this is the loop to fill up the WLC fit wave
		//We will be filling up, in stepwise manner, a wave with extension values following the WLC+Se equation
		//F*p/kT = length/L - F/Se + 0.25/(1-length/L+F/Se)^2-0.25
		RHS = pL/kT * force[j]		
		LHS = testlength/L - force[j]/Se + 0.25/(1-testlength/L+force[j]/Se)^2 - 0.25
		FindLevel/P/Q LHS, RHS		// find where LHS corresponds to RHS
		if (V_flag == 1)
	//		print "No Levels found"
			break
		elseif (V_flag == 0)
			length[j] = testlength[V_LevelX]
		endif
		j += 1	
	while (j < numpnts(LHS))		
	FindLevel/P/Q force, 400
	force += YOffset
	length += XOffset
	Duplicate/O/R=[0, V_LevelX] force, $waveY
	Duplicate/O/R=[0, V_LevelX] length, $waveX
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
	
  	FitParam[DisplayNo][PeakNumber][%WLCSe_p] = pL
 	FitParam[DisplayNo][PeakNumber][%WLCSe_L] = L	
 	
 	 if ( FitParam[DisplayNo][PeakNumber+1][%WLCSe_L] > 0)
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%WLCSe_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%WLCSe_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%WLCSe_L] > 0)
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%WLCSe_L]
 		FitParam[DisplayNo][PeakNumber][%WLCSe_Delta] = DeltaL 
 	endif
 	FitParam[DisplayNo][PeakNumber][%WLCSe_Se]= Se
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][%nCurves] = 1		// # curves
 	FitParam[DisplayNo][PeakNumber][%Model] = 1		// Model
 	
 	Tagname = "Tag" + num2str(PeakNumber)
 	Tag/W=ForceExtensionAnalysis/K/N=$Tagname
	if (t == 1)
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rS\Be\M = "+num2str(Se) +" pN"
 		Tag/W=ForceExtensionAnalysis/N=Tagname/F=2/X=-10/Y=60 $waveY, 10, Taginfo 					
 	endif	
 	KillWaves/Z force, length, LHS, testlength			 		
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayEachFJC()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR Kuhn = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Chisq=root:FX_Analysis:Fits:Variables:chisq
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, LC, CursorA, PeakNumber, XOffset, YOffset
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))
	
	Make/O/N=2000 force, length, Arg, numofsegs	
	Force = p
	CursorA = pcsr(A, "ForceExtensionAnalysis")
	for (i = 20; i >= 0; i -= 1)		
		if (CursorA < FitParam[DisplayNo][i][0])
			PeakNumber = i
		endif
	endfor	
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)		
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	

	//x=((1/tanh(kuhn/kT*Force))-(kT/(Kuhn*Force)) * (ContourLength + (Force*(numofsegments/segmentelasticity)))
	Arg = Kuhn/kT * force
	numofsegs = L/Kuhn			
	length = ((1/tanh(Arg))-(1/Arg))*L
	FindLevel/P/Q force, 400
	force += YOffset
	length += XOffset
	Duplicate/O/R=[0, V_LevelX] force, $waveY
	Duplicate/O/R=[0, V_LevelX] length, $waveX	
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
				
 	FitParam[DisplayNo][PeakNumber][%FJC_p] = Kuhn
 	FitParam[DisplayNo][PeakNumber][%FJC_L] = L
 	
 	 if ( FitParam[DisplayNo][PeakNumber+1][%FJC_L] > 0)
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%FJC_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%FJC_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%FJC_L] > 0)
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%FJC_L]
 		FitParam[DisplayNo][PeakNumber][%FJC_Delta] = DeltaL 
 	endif
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][%nCurves] = 1	// # curves
 	FitParam[DisplayNo][PeakNumber][%Model] = 2	// Model
 	
 	Tagname = "Tag" + num2str(PeakNumber)
	Tag/W=ForceExtensionAnalysis/K/N=Tagname
	if (t == 1)
 		Taginfo ="Kuhn = "+num2str(Kuhn)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL) + " nm"
 		if (f == 2)
 			Taginfo += "\rChisq = "+num2str(Chisq)
 		endif
 		Tag/W=ForceExtensionAnalysis/N=$Tagname/F=2/X=-10/Y=60 $waveY, 10, Taginfo 					
 	endif
 	KillWaves/Z force, length, Arg, numofsegs
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayEachFJCSe()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR Kuhn=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL=root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR Se = root:FX_Analysis:Fits:Variables:SegmentElasticity
	NVAR Chisq = root:FX_Analysis:Fits:Variables:chisq
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR f = root:FX_Analysis:Fits:SetLtoCursor
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, LC, CursorA, PeakNumber, XOffset, YOffset
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 force, length, Arg, numofsegs	
	
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))
	CursorA = pcsr(A, "ForceExtensionAnalysis")
	Force = p
	for (i = 20; i >= 0; i -= 1)		
		if (CursorA < FitParam[DisplayNo][i][0])
			PeakNumber = i
		endif
	endfor	
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)	
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	

	//x=((1/tanh(kuhn/kT*Force))-(kT/(Kuhn*Force)) * (ContourLength + (Force*(numofsegments/segmentelasticity)))
	Arg = Kuhn/kT * force
	numofsegs = L/Kuhn			
	length = ((1/tanh(Arg))-(1/Arg))*(L + (force * (numofsegs/Se)))	
	FindLevel/P/Q force, 400
	force += YOffset
	length += XOffset
	Duplicate/O/R=[0, V_LevelX] force, $waveY
	Duplicate/O/R=[0, V_LevelX] length, $waveX			
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX
	
 	FitParam[DisplayNo][PeakNumber][%FJCSe_p] = Kuhn
 	FitParam[DisplayNo][PeakNumber][%FJCSe_L] = L
 	
 	 if ( FitParam[DisplayNo][PeakNumber+1][%FJCSe_L] > 0)
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%FJCSe_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%FJCSe_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%FJCSe_L] > 0)
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%FJCSe_L]
 		FitParam[DisplayNo][PeakNumber][%FJCSe_Delta] = DeltaL 
 	endif
 	FitParam[DisplayNo][PeakNumber][FitParam[DisplayNo][PeakNumber][%FJCSe_Se]] = Se
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][FitParam[DisplayNo][PeakNumber][%CursorA]] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][FitParam[DisplayNo][PeakNumber][%CursorB]] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][FitParam[DisplayNo][PeakNumber][%nCurves]] = 1		// # curves
 	FitParam[DisplayNo][PeakNumber][FitParam[DisplayNo][PeakNumber][%Model]] = 3		// Model

	Tagname = "Tag" + num2str(PeakNumber)
	Tag/W=ForceExtensionAnalysis/K/N=Tagname
	if (t == 1)
 		Taginfo ="Kuhn = "+num2str(Kuhn)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rS\Be\M = "+num2str(Se) +" pN/nm"
 		if (f == 2)
 			Taginfo += "\rChisq = "+num2str(Chisq)
 		endif
 		Tag/W=ForceExtensionAnalysis/N=$Tagname/F=2/X=-10/Y=60 $waveY, 10, Taginfo 					
 	endif				
 	KillWaves/Z force, length, Arg, numofsegs
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayEachLidavaru()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable radians, i, pb, LC, b=0.154, beta=2, CursorA, PeakNumber, XOffset, YOffset
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, CurrentWave=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 Force, yW, realW, imagW, W, Inverse, zet, finalz
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))
	CursorA = pcsr(A, "ForceExtensionAnalysis")	
	b=0.154
	radians = Angle/360 * 2 * Pi	//convert from degree to radians
	pb = cos(radians/2) / abs(ln(cos(radians)))
	pL = b* pb
//	N = L / (b * cos(radians/2) )
//	Ftrans = 4 * kT * p/b^2	
	for (i = 20; i >= 0; i -= 1)		
		if (CursorA < FitParam[DisplayNo][i][0])
			PeakNumber = i
		endif
	endfor	
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)	
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	
	
	Force = p
	yW = Force * b / kT		// force * b / kT	
	realW =   real ((2 + (4 + (1 - 4/3 * yW * pb )^3 )^(1/2) )^(1/3))	// real part
	imagW = imag((2 + (4 + (1 - 4/3 * yW * pb)^3 )^(1/2) )^(1/3))	// imaginary part
	W = sqrt (realW^2 + imagW^2)								
	Inverse = (4/3 * yW * pb - 1) / W + W
	zet = 1- ( Inverse ^beta + (c * yW)^beta ) ^ (-1/beta) 

	finalz = zet * L
	FindLevel/P/Q Force, 400
	Force += YOffset
	finalz += XOffset
	Duplicate/O/R=[0, V_LevelX] Force, $waveY
	Duplicate/O/R=[0, V_LevelX] finalz, $waveX		
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX

 	FitParam[DisplayNo][PeakNumber][%FRC_p] = pL
 	FitParam[DisplayNo][PeakNumber][%FRC_L] = L 	
 	 if ( FitParam[DisplayNo][PeakNumber+1][%FRC_L] > 0)
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%FRC_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%FRC_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%FRC_L] > 0)
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%FRC_L]
 		FitParam[DisplayNo][PeakNumber][%FRC_Delta] = DeltaL 
 	endif
 	FitParam[DisplayNo][PeakNumber][%FRC_Angle] = Angle
 	FitParam[DisplayNo][PeakNumber][%FRC_c] = c
 	FitParam[DisplayNo][PeakNumber][%FRC_b] = b
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][%nCurves] = 1		// # curves
 	FitParam[DisplayNo][PeakNumber][%Model] = 4		// Model

	Tagname = "Tag" + num2str(PeakNumber)
	Tag/W=ForceExtensionAnalysis/K/N=$Tagname
	if (t == 1)
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rBond Angle = "+num2str(Angle)+"°\rBondlength = "
 		Taginfo += num2str(b)+" nm\rc = "+num2str(c)
 		Tag/W=ForceExtensionAnalysis/N=Tagname/F=2/X=-10/Y=60 $waveY, 40, Taginfo 					
 	endif	
	KillWaves/Z Force, yW, realW, imagW, W, Inverse, zet, finalz
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayEachLidavaruSe()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL = root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L = root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL = root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Angle = root:FX_Analysis:Fits:Variables:BondAngle
	NVAR c = root:FX_Analysis:Fits:Variables:c
	NVAR GammaTilda = root:FX_Analysis:Fits:Variables:SegmentElasticity	
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable radians, i, pb, LC, b=0.154, beta=2, XOffset, YOffset, CursorA, PeakNumber
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, CurrentWave=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 Force, yW, realW, imagW, W, Inverse, zet, finalz
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",CurrentWave))
	CursorA = pcsr(A, "ForceExtensionAnalysis")
	
	b=0.154
	radians = Angle/360 * 2 * Pi	//convert from degree to radians
	pb = cos(radians/2) / abs(ln(cos(radians)))
	pL = b* pb
//	N = L / (b * cos(radians/2) )
//	Ftrans = kT * p/b^2	
	for (i = 20; i >= 0; i -= 1)		
		if (CursorA < FitParam[DisplayNo][i][0])
			PeakNumber = i
		endif
	endfor	
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)	
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	
	
	Force = p
	yW = Force * b / kT		// force * b / kT	
	realW =   real ((2 + (4 + (1 - 4/3 * yW * pb )^3 )^(1/2) )^(1/3))	// real part
	imagW = imag((2 + (4 + (1 - 4/3 * yW * pb)^3 )^(1/2) )^(1/3))	// imaginary part
	W = sqrt (realW^2 + imagW^2)								
	Inverse = (4/3 * yW * pb - 1) / W + W
	zet = 1- ( Inverse ^beta + (c * yW)^beta ) ^ (-1/beta) + Force/GammaTilda
	
	finalz = zet * L		
	FindLevel/P/Q Force, 400
	Force += YOffset
	finalz += XOffset
	Duplicate/O/R=[0, V_LevelX] Force, $waveY
	Duplicate/O/R=[0, V_LevelX] finalz, $waveX		
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX

 	FitParam[DisplayNo][PeakNumber-1][%FRCSe_p] = pL
 	FitParam[DisplayNo][PeakNumber-1][%FRCSe_L] = L
 	 if ( FitParam[DisplayNo][PeakNumber+1][%FRCSe_L] > 0)
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%FRCSe_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%FRCSe_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%FRCSe_L] > 0)
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%FRCSe_L]
 		FitParam[DisplayNo][PeakNumber][%FRCSe_Delta] = DeltaL 
 	endif
 	FitParam[DisplayNo][PeakNumber][%FRCSe_Angle] = Angle
 	FitParam[DisplayNo][PeakNumber][%FRCSe_c] = c
 	FitParam[DisplayNo][PeakNumber][%FRCSe_b] = b
 	FitParam[DisplayNo][PeakNumber][%FRCSe_Se] = GammaTilda
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][%nCurves] = 1		// # curves
 	FitParam[DisplayNo][PeakNumber][%Model] = 5		// Model

	Tagname = "Tag" + num2str(PeakNumber)
	Tag/W=ForceExtensionAnalysis/K/N=Tagname
	if (t == 1)
 		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rBond Angle = "+num2str(Angle)+"°\rS\Be\M = "+num2str(GammaTilda)+" pN/nm\rBondlength = "
 		Taginfo += num2str(b)+" nm\rc = "+num2str(c)
 		Tag/W=ForceExtensionAnalysis/N=$Tagname/F=2/X=-10/Y=60 $waveY, 40, Taginfo 					
 	endif	
	KillWaves/Z Force, yW, realW, imagW, W, Inverse, zet, finalz
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_DisplayEachTC()
	NVAR DisplayNo = root:FX_Analysis:DisplayStartNumber
	NVAR pL=root:FX_Analysis:Fits:Variables:PersistenceLength
	NVAR L=root:FX_Analysis:Fits:Variables:ContourLength
	NVAR DeltaL=root:FX_Analysis:Fits:Variables:ContourLengthincrement
	NVAR t=root:FX_Analysis:Fits:Tags
	NVAR D = root:FX_Analysis:Fits:Variables:ChainThickness
	NVAR a = root:FX_Analysis:Fits:Variables:DiscSeparation
	NVAR t = root:FX_Analysis:Fits:Tags
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i, LC, k1, k2, k3, XOffset, YOffset, CursorA, PeakNumber
	String waveX, waveY, Taginfo, Tagname
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam, W=CsrWaveRef(A, "ForceExtensionAnalysis")
	Make/O/N=2000 force, length, finallength
	XOffset=real(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))		//setup offsets
	YOffset=imag(FX_GetWaveTraceOffset("ForceExtensionAnalysis",W))
	CursorA = pcsr(A, "ForceExtensionAnalysis")	
	length = p/2000
	k1 = -0.28394 + 0.76441 * D/a + 0.31858 * (D/a)^2
	k2 =  0.15989 -  0.50503 * D/a -  0.20636 * (D/a)^2
	k3 = -0.34984 + 1.23330 * D/a + 0.58697 * (D/a)^2
	pL = -a / ln(1 - a^2/4/D^2)
	
	for (i = 20; i >= 0; i -= 1)		
		if (CursorA < FitParam[DisplayNo][i][0])
			PeakNumber = i
		endif
	endfor	
	waveX = "X"+num2str(PeakNumber)
	waveY = "Y"+num2str(PeakNumber)	
	RemoveFromGraph/W=ForceExtensionAnalysis/Z $waveY		//remove old wave	
	
	//force = kT/a/(1-x)* tanh ((k1*x^(3/2) + k2*x^2 + k3*x^3)/(1-x))		
	force = kT/a/(1-length)* tanh ((k1*length^(3/2) + k2*length^2 + k3*(length)^3)/(1-length))			
	FindLevel/P/Q Force, 400
	Force += YOffset
	finallength = (length*L)+XOffset
	Duplicate/O/R=[0, V_LevelX] Force, $waveY
	Duplicate/O/R=[0, V_LevelX] finallength, $waveX	
	AppendToGraph/W=ForceExtensionAnalysis $waveY vs $waveX

 	FitParam[DisplayNo][PeakNumber-1][%TC_p] = pL
 	FitParam[DisplayNo][PeakNumber-1][%TC_L] = L
	 if ( FitParam[DisplayNo][PeakNumber+1][%TC_L] > 0)
 		DeltaL = FitParam[DisplayNo][PeakNumber+1][%TC_L] - L
 		FitParam[DisplayNo][PeakNumber+1][%TC_Delta] = DeltaL 
 	endif
 	if ( PeakNumber > 0 && FitParam[DisplayNo][PeakNumber-1][%TC_L] > 0)
 		DeltaL = L - FitParam[DisplayNo][PeakNumber-1][%TC_L]
 		FitParam[DisplayNo][PeakNumber][%TC_Delta] = DeltaL 
 	endif
 	FitParam[DisplayNo][PeakNumber][%TC_Thick] = D
 	FitParam[DisplayNo][PeakNumber][%TC_Sep] = a
 	if (strlen(CsrInfo(A)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorA] = {pcsr(A)}
 	endif
 	if (strlen(CsrInfo(B)) > 0)
 		FitParam[DisplayNo][PeakNumber][%CursorB] = {pcsr(B)}
 	endif
 	FitParam[DisplayNo][PeakNumber][%nCurves] = 1		// # curves
 	FitParam[DisplayNo][PeakNumber][%Model] = 6		// Model

	Tagname = "Tag" + num2str(PeakNumber)
	Tag/W=ForceExtensionAnalysis/K/N=Tagname
	if (t == 1)
		Taginfo ="p = "+num2str(pL)+" nm\rL\BC\M = "+num2str(L)+" nm\r\F'Symbol'D\F'Arial'L = "+num2str(DeltaL)
 		Taginfo += " nm\rChain Thickness = "+num2str(D)+" nm\rDisc Separation = "+num2str(a)+" nm"
 		Tag/W=ForceExtensionAnalysis/N=$Tagname/F=2/X=-10/Y=60 $waveY, 400, Taginfo 					
 	endif
 	KillWaves/Z force, length
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function/C FX_GetWaveTraceOffset(graphName, w)	// returns offset of given wave, xoffset is real part, yoffset is imaginary part
	String graphName		// Name of graph or "" for top graph.
	Wave w
	String s= TraceInfo(graphName,NameOfWave(w),0)
	
	if (strlen(s) == 0)
		return NaN
	endif
	String subs= "offset(x)={"
	Variable v1= StrSearch(s,subs,0)
	if( v1 == -1 )
		return NaN
	endif
	v1 += strlen(subs)
	Variable xoff= str2num(s[v1,1e6])
	v1= StrSearch(s,",",v1)
	Variable yoff= str2num(s[v1+1,1e6])
	return cmplx(xoff,yoff)
End

//********************************************************************************************************************************
Function LVFitWLC(w,x) : FitFunc
	Wave w
	Variable x
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = (kT/p)*((0.25*(1.00-x/L)^-2.00)-0.25+x/L)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 2
	//CurveFitDialog/ w[0] = p
	//CurveFitDialog/ w[1] = L

	return (kT/w[0])*((0.25*(1.00-x/w[1])^-2.00)-0.25+x/w[1])
End

//********************************************************************************************************************************
Function LVFitFJC(w,F) : FitFunc
	Wave w
	Variable F
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(F) = (1 / tanh (F*Kuhn/kT) - kT/F/Kuhn) * Lc
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ F
	//CurveFitDialog/ Coefficients 2
	//CurveFitDialog/ w[0] = Kuhn
	//CurveFitDialog/ w[1] = Lc

	return (1 / tanh (F*w[0]/kT) - kT/F/w[0]) * w[1]
End

//********************************************************************************************************************************
Function LVFitFJCSe(w,F) : FitFunc
	Wave w
	Variable F
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(F) = (1 / tanh (F*Kuhn/kT) - kT/F/Kuhn) * Lc * (1 + F/Kuhn/Se)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ F
	//CurveFitDialog/ Coefficients 3
	//CurveFitDialog/ w[0] = Kuhn
	//CurveFitDialog/ w[1] = Lc
	//CurveFitDialog/ w[2] = Se

	return (1 / tanh (F*w[0]/kT) - kT/F/w[0]) * w[1] * (1 + F/w[0]/w[2])
End
//********************************************************************************************************************************
Function FX_DeleteWaves(ctrlName) : ButtonControl
	String ctrlName
	NVAR displaynumber = root:FX_Analysis:DisplayNumber
	NVAR displaystartnumber = root:FX_Analysis:DisplayStartNumber
	NVAR nextwavenumber = root:FX_Analysis:nextwavenumber
	NVAR FXrecorded = root:Data:WriteFileNumber
	SVAR Length = root:FX_Analysis:LengthWaveName
	SVAR Force = root:FX_Analysis:ForceWaveName
	String Extension_Fdel, Extension_Bdel, Force_Fdel, Force_Bdel
	String Extension_Fnew, Extension_Bnew, Force_Fnew, Force_Bnew
	String Extension_Fcorr_del, Extension_Bcorr_del, Force_Fcorr_del, Force_Bcorr_del
	String Extension_Fcorr_new, Extension_Bcorr_new, Force_Fcorr_new, Force_Bcorr_new
	Variable counter = displaystartnumber		// first wave to delete
	Variable endcounter = nextwavenumber + 1	// next wave to keep
	Variable i, recorded
	SetDataFolder root:Data
	recorded = FXrecorded
	Doalert 1,"Are you sure you want to delete the selected waves?"
	if(V_Flag==1)	
		Dowindow/K ForceExtensionAnalysis	// Kill Window
		do
			Extension_Fnew = Length + "F" + num2str(endcounter)
			if(WaveExists($Extension_Fnew)==0)
				break
			endif
			Extension_Fdel = Length + "F" + num2str(counter)
			Extension_Bdel = Length + "B" + num2str(counter)
			Force_Fdel = Force + "F" + num2str(counter)
			Force_Bdel = Force + "B" + num2str(counter)		
			Extension_Bnew = Length + "B" + num2str(endcounter)
			Force_Fnew = Force + "F" + num2str(endcounter)
			Force_Bnew = Force + "B" + num2str(endcounter)									
			Duplicate/O $Extension_Fnew, $Extension_Fdel
			Duplicate/O $Extension_Bnew, $Extension_Bdel
			Duplicate/O $Force_Fnew, $Force_Fdel
			Duplicate/O $Force_Bnew, $Force_Bdel		
			// need to deal with corrected waves as well 
			if (StringMatch(Length, "ExtensionRaw_") == 1)	// if raw extension was saved 
				Extension_Fcorr_new = "Extension_F" + num2str(endcounter)
				Extension_Fcorr_del = "Extension_F" + num2str(counter)
				Extension_Bcorr_del = "Extension_B" + num2str(counter)
				Force_Fcorr_del = "Force_F" + num2str(counter)
				Force_Bcorr_del = "Force_B" + num2str(counter)		
				if (WaveExists($Extension_Fcorr_new)==1)	// if new extension exists, copy to the one to be deleted			
					Extension_Bcorr_new = "Extension_B" + num2str(endcounter)
					Force_Fcorr_new = "Force_F" + num2str(endcounter)
					Force_Bcorr_new = "Force_B" + num2str(endcounter)									
					Duplicate/O $Extension_Fcorr_new, $Extension_Fcorr_del
					Duplicate/O $Extension_Bcorr_new, $Extension_Bcorr_del
					Duplicate/O $Force_Fcorr_new, $Force_Fcorr_del
					Duplicate/O $Force_Bcorr_new, $Force_Bcorr_del	
				elseif (WaveExists($Extension_Fcorr_del)==1) // if new extension doesn't exists, just delete
					KillWaves/Z $Extension_Fcorr_del, $Extension_Bcorr_del
					KillWaves/Z $Force_Fcorr_del, $Force_Bcorr_del
				endif	
			endif			
			counter +=  1
			endcounter += 1
		while(endcounter < recorded)
		DoUpdate
		for( i=0; i < (nextwavenumber - displaystartnumber +1); i+=1 )
			Extension_Fdel = Length + "F" + num2str(i+counter)
			Extension_Bdel = Length + "B" + num2str(i+counter)
			Force_Fdel = Force + "F" + num2str(i+counter)
			Force_Bdel = Force + "B" + num2str(i+counter)
			Killwaves/Z $Extension_Fdel, $Extension_Bdel, $Force_Fdel, $Force_Bdel
			// delete corrected waves if they exist
			if (StringMatch(Length, "ExtensionRaw_") == 1)	// if raw extension was saved 
				Extension_Fcorr_del = "Extension_F" + num2str(i+counter)
				if (WaveExists($Extension_Fcorr_del)==1)
					Extension_Bcorr_del = "Extension_B" + num2str(i+counter)
					Force_Fcorr_del = "Force_F" + num2str(i+counter)
					Force_Bcorr_del = "Force_B" + num2str(i+counter)	
					Killwaves/Z $Extension_Fcorr_del, $Extension_Bcorr_del, $Force_Fcorr_del, $Force_Bcorr_del	
				endif
			endif
			Doupdate
		endfor
		FXrecorded = counter
		if (displaystartnumber != 0)
			displaystartnumber -= 1
		endif
		Display_FX_Recordings("",1,"","")
	endif	
end

//********************************************************************************************************************************
Function FX_FindPeaksForward(ctrlName) : ButtonControl
	String ctrlName
	NVAR PeakStartRef=root:FX_Analysis:PeakStartRef
	NVAR PeakDetectorLevel=root:FX_Analysis:PeakDetectorLevel
	NVAR PeakSmooth = root:FX_Analysis:PeakDetectorSmooth
	String command, WaveRef
	SetDataFolder root:Data
	if (strlen(CsrInfo(A,  "ForceExtensionAnalysis")) == 0)	
		print "Please put cursor A on trace!"
		return 0
	endif
	WaveRef=CsrWave(A,  "ForceExtensionAnalysis")
	PeakStartRef = pcsr(A,  "ForceExtensionAnalysis") - 40
	command = "FindAPeak " + num2str(PeakDetectorLevel) + ", 1, " + num2str(PeakSmooth) + ", "
	command += WaveRef + "[" + num2str(PeakStartRef) + ", " + num2str(numpnts($WaveRef)) + "]"
	Execute command
//	FindPeak/B=10/M=(PeakDetectorLevel)/P/Q/R=[PeakStartRef, numpnts($WaveRef)] $WaveRef
//		cursor/P B,$WaveRef, V_PeakLoc
//		cursor/P A,$WaveRef, V_PeakLoc-100
//		PeakStartRef=V_PeakLoc+10
	NVAR V_PeakLoc = V_PeakP
	cursor/P B,$WaveRef, V_PeakLoc
	cursor/P A,$WaveRef, V_PeakLoc+50
//		PeakStartRef=V_PeakP+10

End

//********************************************************************************************************************************
Function FX_FindPeaksBackward(ctrlName) : ButtonControl
	String ctrlName
	NVAR PeakStartRef=root:FX_Analysis:PeakStartRef
	NVAR PeakDetectorLevel=root:FX_Analysis:PeakDetectorLevel
	NVAR PeakSmooth = root:FX_Analysis:PeakDetectorSmooth
	String command, WaveRef
	SetDataFolder root:Data
	if (strlen(CsrInfo(A)) == 0)
		print "Please put cursor A on trace!"
		return 0
	endif
	WaveRef=CsrWave(A,  "ForceExtensionAnalysis")
	PeakStartRef = pcsr(A,  "ForceExtensionAnalysis") - 60
	command = "FindAPeak " + num2str(PeakDetectorLevel) + ", 1, " + num2str(PeakSmooth) + ", "
	command += WaveRef + "[" + num2str(PeakStartRef) + ", 0]"
	Execute command
	NVAR V_PeakLoc = V_PeakP
	cursor/P B,$WaveRef, V_PeakLoc
	cursor/P A,$WaveRef, V_PeakLoc+50
//		FindPeak/B=10/M=(PeakDetectorLevel)/P/Q/R=[PeakStartRef-100,0] $WaveRef
//		cursor/P B,$WaveRef, V_PeakLoc
//		cursor/P A,$WaveRef, V_PeakLoc-100
//		PeakStartRef=V_PeakLoc+10
End

//********************************************************************************************************************************
Function FX_EnterValues(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayNumber = root:FX_Analysis:DisplayStartNumber
	Variable i=-1, Force, Position
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Force = vcsr(B, "ForceExtensionAnalysis")		//B cursor is set to the peak
	Position = pcsr(B, "ForceExtensionAnalysis")
	do
		i += 1
	while (FitParam[DisplayNumber][i][0] > 0)
	FitParam[DisplayNumber][i][0] = Position
	FitParam[DisplayNumber][i][1] = Force
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FX_Histp(ctrlName) : ButtonControl
	String ctrlName
	NVAR Model = root:FX_Analysis:PolymerElasticityModel
	NVAR NumEvents = root:FX_Analysis:HistpNumEvents
	Variable i, binstart=0, binwidth=0.05, numBins=30	
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Make/O/N=(1000,20) pMatrix = 0
	pMatrix = FitParam[p][q][%WLC_p]
	Prompt binstart, "Enter first bin of Histogram: "
	Prompt binwidth, "Enter binwidth: "
	Prompt numBins, "Enter number of bins: "
	DoPrompt "Please enter values", binstart, binwidth, numBins
	if (V_Flag)
		return -1
	endif
	Make/O/N=(numBins) pHistWave
	Histogram/B={binstart, binwidth, numBins} pMatrix, pHistWave
	NumEvents = 0
	for (i = 0; i < numBins; i += 1)
		NumEvents += pHistWave[i]
	endfor
	DoWindow pHistogram
	if (V_Flag == 1)
		RemoveFromGraph/W=pHistogram pHistWave
	else
		Display/W=(550,500,850,700)
		DoWindow/C pHistogram
	endif
	AppendToGraph/W=pHistogram pHistWave
	ModifyGraph/W=pHistogram mode(pHistWave)=5,hbFill(pHistWave)=5
	Label bottom "Persistence Length (nm)"
	Label left "# Occurrences"
	TextBox/W=pHistogram/C/N=text4/F=0/B=1/A=LT "# of Events =" + num2str(NumEvents)
	KillWaves pMatrix
End

//********************************************************************************************************************************
Function FX_HistL(ctrlName) : ButtonControl
	String ctrlName
	NVAR NumEvents = root:FX_Analysis:HistLcNumEvents
	Variable i, binstart=0, binwidth=10, numBins=30
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Make/O/N=(1000,20) LMatrix = 0
	LMatrix = FitParam[p][q][%WLC_L]
	Prompt binstart, "Enter first bin of Histogram: "
	Prompt binwidth, "Enter binwidth: "
	Prompt numBins, "Enter number of bins: "
	DoPrompt "Please enter values", binstart, binwidth, numBins
	if (V_Flag)
		return -1
	endif
	Make/O/N=(numBins) LHistWave
	Histogram/B={binstart, binwidth, numBins} LMatrix, LHistWave
	NumEvents = 0
	for (i = 0; i < numBins; i += 1)
		NumEvents += LHistWave[i]
	endfor
	DoWindow LHistogram
	if (V_Flag == 1)
		RemoveFromGraph/W=LHistogram LHistWave
	else
		Display/W=(550,500,850,700)
		DoWindow/C LHistogram
	endif
	AppendToGraph/W=LHistogram LHistWave
	ModifyGraph/W=LHistogram mode=5,hbFill=5, rgb=(0,15872,65280)
	Label bottom "Contour Length (nm)"
	Label left "# Occurrences"
	TextBox/W=LHistogram/C/N=text3/F=0/B=1/A=LT "# of Events =" + num2str(NumEvents)
	KillWaves LMatrix
End

//********************************************************************************************************************************
Function FX_HistDelta(ctrlName) : ButtonControl
	String ctrlName
	NVAR NumEvents = root:FX_Analysis:HistDeltaNumEvents
	Variable i, j, binstart=5, binwidth=1, numBins=40
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Make/O/N=(1000,20) DeltaMatrix = 0
	DeltaMatrix = FitParam[p][q][%WLC_Delta]
	Prompt binstart, "Enter first bin of Histogram: "
	Prompt binwidth, "Enter binwidth: "
	Prompt numBins, "Enter number of bins: "
	DoPrompt "Please enter values", binstart, binwidth, numBins
	if (V_Flag)
		return -1
	endif
	Make/O/N=(numBins) DeltaHistWave
	Histogram/B={binstart, binwidth, numBins} DeltaMatrix, DeltaHistWave
	NumEvents = 0
	for (i = 0; i < numBins; i += 1)
		NumEvents += DeltaHistWave[i]
	endfor
	DoWindow DeltaHistogram
	if (V_Flag == 1)
		RemoveFromGraph/W=DeltaHistogram DeltaHistWave
	else
		Display/W=(550,500,850,700)
		DoWindow/C DeltaHistogram
	endif
	AppendToGraph/W=DeltaHistogram DeltaHistWave
	ModifyGraph/W=DeltaHistogram mode=5,hbFill=5, rgb=(0,39168,0)
	Label bottom "Increase in Contour Length (nm)"
	Label left "# Occurrences"
	TextBox/W=DeltaHistogram/C/N=text1/F=0/B=1/A=LT "# of Events =" + num2str(NumEvents)
	KillWaves DeltaMatrix
End

//********************************************************************************************************************************
Function FX_HistForces(ctrlName) : ButtonControl
	String ctrlName
	NVAR NumEvents = root:FX_Analysis:HistForcesNumEvents
	Variable i, j, binstart=50, binwidth=5, numBins=50, average=0
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Make/O/N=(dimsize(FitParam,0),dimsize(FitParam,1)) ForceMatrix = 0
	ForceMatrix = FitParam[p][q][%Force]
	Prompt binstart, "Enter first bin of Histogram: "
	Prompt binwidth, "Enter binwidth: "
	Prompt numBins, "Enter number of bins: "
	DoPrompt "Please enter values", binstart, binwidth, numBins
	if (V_Flag)
		return -1
	endif
	Make/O/N=(numBins) ForceHistWave
	Histogram/B={binstart, binwidth, numBins} ForceMatrix, ForceHistWave
	NumEvents = 0
	for (i = 0; i < numBins; i += 1)
		NumEvents += ForceHistWave[i]
	endfor
	DoWindow ForceHistogram
	if (V_Flag == 1)
		RemoveFromGraph/W=ForceHistogram ForceHistWave
	else
		Display/W=(550,500,850,700)
		DoWindow/C ForceHistogram
	endif
	AppendToGraph/W=ForceHistogram ForceHistWave
	ModifyGraph/W=ForceHistogram mode(ForceHistWave)=5,hbFill(ForceHistWave)=5
	ModifyGraph/W=ForceHistogram rgb(ForceHistWave)=(52224,0,20736)
	Label bottom "Peak forces (pN)"
	Label left "# Occurrences"
	TextBox/W=ForceHistogram/C/N=text2/F=0/B=1/A=LT "# of Events =" + num2str(NumEvents)
	// calculate average force
	for (i = 0; i < dimsize(FitParam,0); i += 1)
		for (j = 0; j < dimsize(FitParam,1); j += 1)
			if (ForceMatrix[i][j] > -1)
				average += ForceMatrix[i][j]
			endif
		endfor
	endfor
	average /= NumEvents
	TextBox/W=ForceHistogram/C/N=text2/F=0/B=1/A=LT "# of Events =" + num2str(NumEvents) + "\raverage = " + num2str(average) + " pN"
	KillWaves ForceMatrix
End

//********************************************************************************************************************************
Function FX_pvsF(ctrlName) : ButtonControl
	String ctrlName
	NVAR Start=root:FX_Analysis:DisplayStartNumber 
	NVAR Temp = root:FX_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable CsrA, i=0, from, to, peak
	String Perswave, CutForce
	SetDataFolder root:FX_Analysis:Fits
	Wave FitParam
	Wave Forcewave = CsrWaveRef(A, "ForceExtensionAnalysis")
	Wave Lengthwave = CsrXWaveRef(A, "ForceExtensionAnalysis")
	SetDataFolder root:FX_Analysis:Persistence
	Perswave = "Persistence0_" +  num2str(Start)
	CutForce = 	"cutForce0_" +  num2str(Start)
	Duplicate/O Forcewave, LCWave
	LCWave = 0
	Duplicate/O Forcewave, Persistence
	// calculate p via WLC using force and length, use LC from previous WLC fits to each peak:
	CsrA = pcsr(A, "ForceExtensionAnalysis")
	LCWave = FitParam[Start][0][%WLC_L]
	do
		from = FitParam[Start][i][%PeakPointNumber] + 10
		to = FitParam[Start][i+1][%PeakPointNumber] + 10
		LCWave[from, to] = FitParam[Start][i+1][%WLC_L]
		i += 1
	while (FitParam[Start][i+1][%PeakPointNumber] > 0)
	Persistence = kT/Forcewave*( Lengthwave/LCWave + 0.25 / (1-Lengthwave/LCWave)^2 - 0.25 )
	Duplicate/O/R=[CsrA, FitParam[Start][0][%PeakPointNumber]] Persistence, $Perswave
	Duplicate/O/R=[CsrA, FitParam[Start][0][%PeakPointNumber]] Forcewave, $CutForce 
	DoWindow/K Persistence_Length
	Display/W=(0,470,550,650)
	DoWindow/C Persistence_Length
	AppendToGraph $Perswave
	i = 1
	do
		Perswave = "Persistence" + num2str(i) + "_" +  num2str(Start)
		CutForce = 	"cutForce" + num2str(i) + "_" +  num2str(Start)
		peak = FitParam[Start][i-1][%PeakPointNumber]		// previous peak
		WaveStats/Q/R=[peak, peak+100]/Z/M=1 Forcewave
		from = x2pnt(Forcewave, V_minloc)			// get minimum after peak
		to = FitParam[Start][i][%PeakPointNumber] 	// next peak
		Duplicate/O/R=[from, to] Persistence, $Perswave
		Duplicate/O/R=[from, to] Forcewave, $CutForce 
		AppendToGraph $Perswave
		i += 1
	while (FitParam[Start][i][%PeakPointNumber] > 0)
	SetAxis left 0,1
	ModifyGraph rgb = (19456,39168,0)
	Label bottom  "Time (\U)"
	Label left "Persistencelength p (nm)"	
	KillWaves/Z LCWave,Persistence
	SetDataFolder root:Data
End


//********************************************************************************************************************************
//Here begins the code for FCAnalysis
//********************************************************************************************************************************

Function Display_FCUncorrected(ctrlName,checked) : CheckBoxControl
	String ctrlName
	Variable checked			// 1 if selelcted, 0 if not
	NVAR Uncorrected = root:FC_Analysis:FCDisplayUncorrected
	Uncorrected = checked
	Display_FC_Recordings()
End

//********************************************************************************************************************************
Function FC_UpdatePlot(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	Display_FC_Recordings()
End

//********************************************************************************************************************************
Function Display_FC_Recordings()
	NVAR FCInfoFlag = root:FC_Analysis:FCInfoFlag
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	NVAR DisplayNumber = root:FC_Analysis:FCDisplayNumber
	NVAR DisplayStartNumber = root:FC_Analysis:FCDisplayStartNumber
	NVAR Nextwavenumber = root:FC_Analysis:FCNextWaveNumber
	NVAR Uncorrected = root:FC_Analysis:FCDisplayUncorrected
	NVAR SC = root:FC_Analysis:SpringConstant
	SVAR Type = root:FC_Analysis:ExpType
	NVAR Temp = root:FC_Analysis:Temperature
	NVAR p = root:FC_Analysis:Fits:WLC:PersistenceLength
	NVAR LC = root:FC_Analysis:Fits:WLC:ContourLength
	NVAR dL = root:FC_Analysis:Fits:WLC:ContourLengthIncrement
	NVAR uL = root:FC_Analysis:Fits:WLC:FoldedLength		// unit length folded
	NVAR Linker = root:FC_Analysis:Fits:WLC:Linker
	NVAR Refolded = root:FC_Analysis:Fits:WLC:Refolded
	NVAR Units = root:FC_Analysis:Fits:WLC:Units
	NVAR Ferror = root:FC_Analysis:Fits:WLC:F_Error
	Variable i, shiftby, to, N, j
	String Force_Wave, Filtered_Force, Shift_Wave, Length_Wave, WLC_Wave
	String Perswave, InfoNote="", Contour, TraceList, normLength
	PauseUpdate
	if(!DataFolderExists("root:Data"))
		DoAlert 0, "Try loading the data first. I need a Data Folder!!!"
		Return 1
	endif
	Nextwavenumber = DisplayNumber + DisplayStartNumber - 1
	// Instead of killing the graph and creating it again, it is better to remove the traces that we do not want.
	// In this way if the user customizes the screen, the changes (for instance the size of the graph) are not lost when next traces is browsed.
	if(WinType("ForceClampAnalysis")==1) 
		DoWindow/F ForceClampAnalysis 
		SetDrawLayer/W=ForceClampAnalysis/K  UserFront
		TraceList = TraceNameList("ForceClampAnalysis", ";", 1 )
		N = ItemsInList(TraceList,";")
		for(j=0; j<N; j+=1)
			RemoveFromGraph/Z/W=ForceClampAnalysis $(StringFromList(j, TraceList,";"))
		endfor
		TraceList = TraceNameList("ForceClampAnalysis", ";", 1 )		// do twice to get rid of both StepStats waves
		N = ItemsInList(TraceList,";")
		for(j=0; j<N; j+=1)
			RemoveFromGraph/Z/W=ForceClampAnalysis $(StringFromList(j, TraceList,";"))
		endfor
	else
		DoWindow/K ForceClampAnalysis
		Display/W=(0,0,550,400)
		DoWindow/C ForceClampAnalysis
		SetWindow ForceClampAnalysis,hook(testhook)=KeyboardPanelHook
	endif
	
	for (i=DisplayStartNumber; i<DisplayStartNumber+DisplayNumber; i+=1)
		SetDataFolder root:Data
		Filtered_Force = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str(i)
		Force_Wave = ForceName + num2str(i)
		if(waveexists($Filtered_Force) && Uncorrected == 0)
			SetDataFolder root:FC_Analysis:Shift
			Force_Wave = "filtered_" + ForceName + num2str(i)
			Length_Wave = "shift_" + LengthName + num2str(i)
			Wave length = $Length_Wave
			AppendToGraph/W=ForceClampAnalysis /L=ForceAxis $Filtered_Force
			AppendToGraph/W=ForceClampAnalysis $Length_Wave
			FindLevel/Q length, 600
			if (V_Flag == 0)
				to = V_LevelX
				SetAxis/W=ForceClampAnalysis bottom 0, to
				WaveStats/M=1/Q/R=(0, to-0.1) length
				SetAxis/W=ForceClampAnalysis left V_min, V_max+20
			endif
		elseif(waveexists($Force_Wave))
			Length_Wave= LengthName + num2str(i)
			Wave length = $Length_Wave
			AppendToGraph/W=ForceClampAnalysis/L=ForceAxis $Force_Wave
			AppendToGraph/W=ForceClampAnalysis $Length_Wave
			WaveStats/Q/M=0 length
			FindLevel/Q length, (V_min + 500)
			if (V_Flag == 0)
				to = V_LevelX
				SetAxis/W=ForceClampAnalysis bottom 0, to
					//SetAxis bottom 0,6
				WaveStats/M=1/Q/R=(0, to-0.5) length
				SetAxis/W=ForceClampAnalysis left V_min, V_max+20
			endif
		else
			SetDrawLayer/W=ForceClampAnalysis  UserFront
			SetDrawEnv/W=ForceClampAnalysis  xcoord=rel, ycoord =rel,fsize= 14, textrgb= (39168,39168,39168),textxjust= 1,textyjust= 1
			DrawText/W=ForceClampAnalysis 0.5,0.5 , "No data by the name of "+ Force_Wave
			return i
		endif
		WaveStats/M=1/Q $Force_Wave
		//SetAxis/W=ForceClampAnalysis ForceAxis, V_min+400, 30
		SetAxis/W=ForceClampAnalysis ForceAxis, -630, 110
		shiftby=400*(i-DisplayStartNumber)
		ModifyGraph/W=ForceClampAnalysis rgb($Force_Wave)=(0,0,0), offset($Force_Wave)={0,shiftby}
		ModifyGraph/W=ForceClampAnalysis grid(ForceAxis)=1, axisEnab(ForceAxis)={0,0.35}
		ModifyGraph/W=ForceClampAnalysis freePos(ForceAxis)={0,bottom}, lblPos(ForceAxis)=50				
		ModifyGraph/W=ForceClampAnalysis offset($Length_Wave)={0,shiftby}, axisEnab(Left)={0.4,1}
		ModifyGraph/W=ForceClampAnalysis grid(left)=1,nticks(left)=10, lblPos(left)=50
		ModifyGraph gridRGB(ForceAxis)=(39168,39168,39168)
		ModifyGraph gridRGB(left)=(39168,39168,39168)
		Label/W=ForceClampAnalysis ForceAxis "Force (pN)"
		Label/W=ForceClampAnalysis bottom  "Time (\U)"	
		Label/W=ForceClampAnalysis left "Length (nm)"
		ModifyGraph/W=ForceClampAnalysis lblPosMode(ForceAxis)=2
		ModifyGraph/W=ForceClampAnalysis lblPosMode(left)=2
		ShowInfo/W=ForceClampAnalysis
		AddInfoStamp()
		InfoNote = note($Force_Wave)	
		if (FCInfoFlag == 1)
			SC = NumberByKey(" SC(pN/nm)", InfoNote, "=")
			if (SC > 0)
			else
				SC = NumberByKey(" SC", InfoNote, "=")
			endif
			Type = StringByKey(" Type", InfoNote, "=")
			if (NumberByKey(" T(C)", InfoNote, "=") > -10000)
				Temp = NumberByKey(" T(C)", InfoNote, "=")
			endif
		else
			NVAR GSC = root:Data:G_SpringConstant
			SC = GSC
			Type = ""
		endif
		SetDataFolder root:FC_Analysis:Fits:WLC
		WLC_Wave = "WLC_Length" + num2str(i)
		if(waveexists($WLC_Wave))
			AppendToGraph/W=ForceClampAnalysis $WLC_Wave
			ModifyGraph/W=ForceClampAnalysis rgb($WLC_Wave)=(0,12800,52224)
			InfoNote = note($WLC_Wave)	
			p = NumberByKey("p", InfoNote, "=")
			LC = NumberByKey(" LC", InfoNote, "=")
			dL = NumberByKey(" DeltaL", InfoNote, "=")
			uL = NumberByKey(" UnfoldedLength", InfoNote, "=")
			Units = NumberByKey(" Units", InfoNote, "=")
			Refolded = NumberByKey(" Refolded", InfoNote, "=")
			Linker = NumberByKey(" LinkerLength", InfoNote, "=")
			Ferror = NumberByKey(" ErrorInForce", InfoNote, "=")
		else
			p = 0.4
			LC = 100
			dL = 19.35		// I27=28.4	Ubi=23.56	ProteinL=19.35
			uL = 3.7		// I27=4.5	Ubi=3.8	ProteinL=3.7
			Units = 1
			Refolded = 0
			Linker = 10
			Ferror = 0
		endif
		FC_RedrawLines()
//		SetDataFolder root:FC_Analysis:Fits:PersistenceData		// display persistence length
//		Perswave = "Persistence_Length" +  num2str(i)	
//		if (WaveExists($Perswave)	)	
//			if(WinType("Persistence_Length")==1) 
//				DoWindow/F Persistence_Length
//				SetDrawLayer/W=Persistence_Length/K  UserFront
//				TraceList = TraceNameList("Persistence_Length", ";", 1 )
//				N = ItemsInList(TraceList,";")
//				for(j=0; j<N; j+=1)
//					RemoveFromGraph/Z/W=Persistence_Length $(StringFromList(j, TraceList,";"))
//				endfor
//			else
//				DoWindow/K Persistence_Length
//				Display/W=(0,470,550,650)
//				DoWindow/C Persistence_Length
////				SetWindow Persistence_Length,hook(testhook)=KeyboardPanelHook
//			endif		
//			AppendToGraph $Perswave
//			GetAxis/W=ForceClampAnalysis/Q bottom
//			SetAxis left 0,1
//			SetAxis bottom V_min, V_max
//			ModifyGraph rgb($Perswave) = (19456,39168,0)
//			Label bottom  "Time (\U)"
//			Label left "Persistencelength p (nm)"
//			ModifyGraph grid(left)=1
//			ShowInfo
//		else
//			DoWindow/K Persistence_Length
//		endif
//		Force_Wave = ForceName + num2str (i)	+ "_down_sm"		//display p vs Force
//		PersWave = "Persistence_Length" +  num2str(i) + "_down_cut"
//		if (WaveExists($Perswave)	)	
//			if(WinType("PvsF")==1) 
//				DoWindow/F PvsF
//				SetDrawLayer/W=PvsF/K  UserFront
//				TraceList = TraceNameList("PvsF", ";", 1 )
//				N = ItemsInList(TraceList,";")
//				for(j=0; j<N; j+=1)
//					RemoveFromGraph/Z/W=PvsF $(StringFromList(j, TraceList,";"))
//				endfor
//			else
//				DoWindow/K PvsF
//				Display/W=(0,470,550,650)
//				DoWindow/C PvsF
////				SetWindow PvsF,hook(testhook)=KeyboardPanelHook
//			endif		
//			AppendToGraph $PersWave vs $Force_Wave
//			ModifyGraph rgb($PersWave) = (19456,39168,0)
//			Force_Wave = ForceName + num2str (i)	+ "_up_sm"
//			PersWave = "Persistence_Length" +  num2str(i) + "_up_cut"
//			AppendToGraph $PersWave vs $Force_Wave
//			ModifyGraph rgb($PersWave) = (26368,0,52224)
//			Label bottom "Force (pN)"
//			Label left "Persistencelength p (nm)"
//			SetAxis left 0,2
//			ModifyGraph grid(left)=1
//			ShowInfo
//		else
//			DoWindow/K PvsF
//		endif			
//		SetDataFolder root:FC_Analysis:Fits:ContourData		// display contour length
//		Contour = "Contour_Length_Unit" +  num2str(i)	
//		if (WaveExists($Contour) )	
//			if(WinType("Contour_Length")==1) 
//				DoWindow/F Contour_Length
//				SetDrawLayer/W=Contour_Length/K  UserFront
//				TraceList = TraceNameList("Contour_Length", ";", 1 )
//				N = ItemsInList(TraceList,";")
//				for(j=0; j<N; j+=1)
//					RemoveFromGraph/Z/W=Contour_Length $(StringFromList(j, TraceList,";"))
//				endfor
//			else
//				DoWindow/K Contour_Length
//				Display/W=(0,470,550,650)
//				DoWindow/C Contour_Length
//			endif		
//			AppendToGraph $Contour
//			GetAxis/W=ForceClampAnalysis/Q bottom
//			SetAxis bottom V_min, V_max
//			SetAxis left 0, 40
//			ModifyGraph rgb($Contour) = (0,52224,52224)
//			Label bottom  "Time (\U)"
//			Label left "Contourlength Lc (nm)"
//			ModifyGraph grid(left)=1
//			ShowInfo
//		else
//			DoWindow/K Contour_Length
//		endif
		SetDataFolder root:FC_Analysis:Fits:xNormData
		normLength = "Norm_Length_down" + num2str(i)
		if (WaveExists($normLength))
			if(WinType("xNormvsF")==1) 
				DoWindow/F xNormvsF
				SetDrawLayer/W=xNormvsF/K  UserFront
				TraceList = TraceNameList("xNormvsF", ";", 1 )
				N = ItemsInList(TraceList,";")
				for(j=0; j<N; j+=1)
					RemoveFromGraph/Z/W=xNormvsF $(StringFromList(j, TraceList,";"))
				endfor
			else	
				DoWindow/K xNormvsF
				Display/W=(0,470,550,650)
				DoWindow/C xNormvsF
			endif
			Force_Wave = ForceName + num2str (i) + "_down_sm"
			AppendToGraph $normLength vs $Force_Wave
			ModifyGraph rgb($normLength) = (65280,21760,0)
			normLength = "Norm_Length_up" + num2str(i)
			Force_Wave = ForceName + num2str (i) + "_up_sm"
			AppendToGraph $normLength vs $Force_Wave
			ModifyGraph rgb($normLength) = (26112,52224,0)
			Label bottom "Force (pN)"
			Label left "normalized Length (nm)"
			ShowInfo
		else
			DoWindow/K xNormvsF
		endif
	endfor
	
	ModifyGraph manTick(left)={0,26,0,0},manMinor(left)={0,0}
	ModifyGraph manTick(bottom)={0,1,0,0},manMinor(bottom)={0,0}
	
	DoWindow/F ForceClampAnalysis
	SetDataFolder root:Data
	KillWaves/Z temp
End

//********************************************************************************************************************************
Function KillFCAnalysisGraph(ctrlName) : ButtonControl
	String ctrlName
	DoWindow/F ForceClampAnalysis
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K ForceClampAnalysis
	endif
	DoWindow/F Persistence_Length
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K Persistence_Length
	endif
	DoWindow/F PvsF
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K PvsF
	endif
	DoWindow/F Contour_Length
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K Contour_Length
	endif
	DoWindow/F xNormvsF
	if(V_Flag==1)	// if there is a window, kill it
		DoWindow/K xNormvsF
	endif
End

//********************************************************************************************************************************
Function FC_Export(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayNr = root:FC_Analysis:FCDisplayStartNumber
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	String Length, Force, ListWaves=""
	Variable Npoints, i
	SetDataFolder root:FC_Analysis
	if (WaveExists(ExportWaves) == 0)
		Make/N=0 ExportWaves
	endif
	Npoints = numpnts(ExportWaves)
	FindValue/V=(DisplayNr) ExportWaves
	if (V_value > -1)	// if value is already stored in wave, export
		DoAlert 1, "Do you want to export all previously selected waves?"
		if (V_Flag == 1)	// ask whether to export
			for (i=0; i<Npoints; i+=1)
				ListWaves += LengthName + num2str(ExportWaves[i]) + ";"
				ListWaves += ForceName + num2str(ExportWaves[i]) + ";"			
			endfor
			SetDataFolder root:Data
			Save/C/B ListWaves
		else
			return 0
		endif
	else
		Redimension/N=(Npoints+1) ExportWaves
		ExportWaves[Npoints] = DisplayNr					
	endif
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FCImportWaves()
	String Foldername="root:"
	Prompt Foldername, "Please enter folder (complete path) into which you would like to import the data (in case of name conflict existing waves are not overwritten):"
	DoPrompt "Destination folder", Foldername
	if (V_Flag)
		return 0		// user canceled
	endif
	if (DataFolderExists(Foldername) == 0)
		NewDataFolder $Foldername
	endif
	SetDataFolder $Foldername
	LoadData/D/I/Q
	
	DoAlert 1, "Do you want to move the data into root:Data: and rename them so that they are continuous?"
	if (V_Flag == 2)
		return 0
	endif
	// continue with moving and renaming
	Variable start=0
	Variable i, k, counter
	String ForceName = "Ramp_Force_Wave", LengthName = "Ramp_Length_Wave", List
	String Forceold, Extold, Forcenew, Extnew
	String WaveOrigin = "Origin of Waves"
	List = WaveList("FC*", ";", "")
	if( ItemsInList(List) > 0)
		ForceName = "FC_Force"
		LengthName = "FC_Length"
	endif	
	if (DataFolderExists ("root:Data") == 0)
		NewDataFolder root:Data
	endif
	DoWindow NotebookOrigin
	if (V_Flag == 1)
		DoWindow/f NotebookOrigin
	else
		NewNotebook/K=2/f=0/n=NotebookOrigin/W=(600,0,800,120) as WaveOrigin
	endif
	do
		Forceold = "root:Data:" + ForceName + num2str(start)
		start += 1
	while (Waveexists($Forceold) == 1)
	start -= 1	
	counter = 0
	for (i = 0; i < 1000; i += 1)
		Forceold = Foldername + ":" + ForceName + num2str(i)
		if (Waveexists($Forceold) == 1)
			Extold = Foldername + ":" + LengthName + num2str(i)
			k = start + counter
			Forcenew = "root:Data:" + ForceName + num2str(k)
			Extnew = "root:Data:" + LengthName + num2str(k)
			Duplicate $Forceold, $Forcenew
			Duplicate $Extold, $Extnew
			counter += 1
		endif
	endfor
	Notebook NotebookOrigin text="Waves " + num2str(start) + " to " + num2str(k) + " from " + Foldername + "\r"
	SetDataFolder root:Data
End

//********************************************************************************************************************************
Function FC_CorrectAll(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayStartNumber = root:FC_Analysis:FCDisplayStartNumber
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	String Length_Wave
	Variable start = DisplayStartNumber
	SetDataFolder root:Data
	DisplayStartNumber = 0
	do
		FC_CorrectOne("")
		DisplayStartNumber += 1
		Length_Wave = LengthName + num2str(DisplayStartNumber)
	while (WaveExists($Length_Wave) != 0)
	DisplayStartNumber = start
	Display_FC_Recordings()
End

//********************************************************************************************************************************
// This shifts Length Curves so that they start at zero and it corrects for the spring constant
Function FC_CorrectOne(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	NVAR SC = root:FC_Analysis:SpringConstant
	NVAR i = root:FC_Analysis:FCDisplayStartNumber
	String Length_Wave, Shift_Wave, Force_Wave, Filtered_Force, InfoNote, command
	Variable Shiftby
	SetDataFolder root:Data
	Make/D/O/N=2 W_coef
	Length_Wave = LengthName + num2str(i)
	Force_Wave = ForceName + num2str(i)
	Shift_Wave = "root:FC_Analysis:Shift:shift_" + LengthName + num2str(i)
	Filtered_Force = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str(i)
	W_coef[1] = 0		
	InfoNote = note($Force_Wave)	
	if (strlen(Infonote) != 0)
		SC = NumberByKey(" SC(pN/nm)", InfoNote, "=")
		if (SC > 0)
		else
			SC = NumberByKey(" SC", InfoNote, "=")
		endif
	else
		NVAR DataSC = root:Data:G_SpringConstant
		SC = DataSC
	endif
	// First correct length for cantilever displacement
	Duplicate/O $Length_Wave, Shift
	Wave Force = $Force_Wave
	Shift += Force/SC	
	CurveFit/Q/H="01" line kwCWave=W_coef, Shift(0.01,0.095) /D		//standard
//	CurveFit/Q/H="01" line kwCWave=W_coef, Shift[10,90] /D	
	Shift -= W_coef[0]
	// Filter force and extension here
//	command = "ApplyFilterToData(\"" + Force_Wave + "\",\"kaiserLowPass900-1100\"," + num2str(1) + "," + num2str(0) +")"
//	Execute command
//	command = "ApplyFilterToData(\"Shift\",\"kaiserLowPass900-1100\"," + num2str(1) + "," + num2str(0) +")"
//	Execute command
	Duplicate/O Shift, $Shift_Wave
	Duplicate/O $Force_Wave, $Filtered_Force
	KillWaves/Z W_coef, Shift, Fit_Shift
End

//********************************************************************************************************************************
Function FC_DeleteWaves(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	NVAR DisplayNumber = root:FC_Analysis:FCDisplayNumber
	NVAR DisplayStartNumber = root:FC_Analysis:FCDisplayStartNumber
	NVAR Nextwavenumber = root:FC_Analysis:FCNextWaveNumber
	NVAR FCrecorded = root:Data:FCWriteFileNumber
	String Force_del, Length_del, Force_new, Length_new
	Variable counter = displaystartnumber
	Variable endcounter = nextwavenumber +1
	Variable i, recorded	
	SetDataFolder root:Data

	recorded = FCrecorded
	
	Doalert 1,"Are you sure you want to delete the selected waves?"
	if(V_Flag==1)
		DoWindow/K ForceClampAnalysis			//need to kill window, otherwise displayed waves can't be deleted
		do
			Force_new = ForceName + num2str(endcounter)
			if(waveexists($Force_new)==0)
				break
			endif	
			Force_del = ForceName + num2str(counter)
			Length_del = LengthName + num2str(counter)			
			Length_new = LengthName + num2str(endcounter)							
			Duplicate/O $Force_new $Force_del
			Duplicate/O $Length_new $Length_del		
			counter += 1
			endcounter += 1
		while(endcounter < recorded)
		DoUpdate
		for ( i = 0; i < (nextwavenumber - displaystartnumber + 1); i += 1)
			Force_del = ForceName + num2str(i+counter)
			Length_del = LengthName + num2str(i+counter)			
			Killwaves/Z $Force_del , $Length_del
			DoUpdate
		endfor
		if(FCrecorded ==0)
			FCrecorded = counter
			print "The number of waves left is: " + num2str(FCrecorded)
		else
			FCrecorded = counter
		endif
		if (displaystartnumber != 0)
			displaystartnumber -= 1
		endif
		Display_FC_Recordings()
	endif	
End

//********************************************************************************************************************************
// This function displays the length given by the WLC and the force trace. Unfolding/refolding
// occurs at the points given in the matrix "Events". Refolding only occurs if the Checkbox
// "Success?" is checked.
Function FC_DisplayWLC()
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	NVAR DisplayStart = root:FC_Analysis:FCDisplayStartNumber
	NVAR Success = root:FC_Analysis:Fits:WLC:Successful
	NVAR Initial = root:FC_Analysis:Initial
	NVAR pL = root:FC_Analysis:Fits:WLC:PersistenceLength
	NVAR LC = root:FC_Analysis:Fits:WLC:ContourLength
	NVAR dL = root:FC_Analysis:Fits:WLC:ContourLengthIncrement
	NVAR uL = root:FC_Analysis:Fits:WLC:FoldedLength	
	NVAR Linker = root:FC_Analysis:Fits:WLC:Linker
	NVAR Refolded = root:FC_Analysis:Fits:WLC:Refolded
	NVAR Units = root:FC_Analysis:Fits:WLC:Units
	NVAR Ferror = root:FC_Analysis:Fits:WLC:F_Error
	NVAR Temp = root:FC_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i=0, from=0, to, Npoints,  j=0, unfolded//, pullingtime, relaxtime
	Variable/C im=sqrt(-1)
	String Force, Length, Contour, UnfoldedWave, Step_Wave, InfoNote=""
	SetDataFolder root:FC_Analysis:Steps
	Step_Wave = "StepStats_" + num2str(DisplayStart)
	Wave StepStats = $Step_Wave //Events
	SetDataFolder root:FC_Analysis:Fits:WLC
	Force = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str (DisplayStart)
	Length = "WLC_Length" + num2str (DisplayStart)
	Contour = "Contour" + num2str (DisplayStart)
	UnfoldedWave = "UnfoldedUnits" + num2str (DisplayStart)
	if (!WaveExists($Force))
		DoAlert 0, "Please correct for cantilever displacement first!"
		return 0
	endif
	Duplicate/D/O $Force, smoothed
	Npoints = numpnts(smoothed)
	Make/D/O/N=(Npoints) LcLength, B, realD, imagD, NoUnfold
	Smooth/B 51, smoothed	//61
	smoothed = -smoothed + Ferror
	// calculating x given F from the WLC requires inverting the equation - messy
	// x = LC/6 * ( 6 - D + 2*B - 4*B^2 /D)
	//    = LC/6 * ( 6 - realD + 2*B - 4*realD*B^2 / (realD^2 + imagD^2) )
	// B = F * p / kT - 0.75
	// D = ( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3)
	B = smoothed * pL / kT - 0.75
	realD = real (( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3))	// real part
	imagD = imag (( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3))	// imaginary part
	unfolded = 0; Refolded = 0; i = 1
	from = 0
	for (i = 1; i < DimSize(StepStats, 0)-1; i += 1)
		to = x2pnt(smoothed, StepStats[i][0])
		NoUnfold[from, to] = j
		LC = Linker + Units * uL + dL * j
		LClength[from, to] = LC
		from = to
		if (StepStats[i][3] >= 0)	// positive step
			j += 1
		else
			j -= 1
			Refolded += 1
		endif		
	endfor
	to = Npoints		// do for remainder of trace
	NoUnfold[from, to] = j
	LC = Linker + Units * uL + dL * j
	LClength[from, to] = LC
	smoothed = LClength/6 * ( 6 - realD + 2*B - 4*realD*B^2 / (realD^2 + imagD^2) )
	Duplicate/O smoothed, $Length
	Duplicate/O LClength, $Contour
	Duplicate/O NoUnfold, $UnfoldedWave
	RemoveFromGraph/Z/W=ForceClampAnalysis $Length
	AppendToGraph/W=ForceClampAnalysis $Length
	ModifyGraph/W=ForceClampAnalysis rgb($Length)=(0,12800,52224)
	DoUpdate
	LC = Linker + Units * (uL + dL)	
	InfoNote = "p=" + num2str(pL) + "; LC=" + num2str(LC) + "; DeltaL=" + num2str(dL)
	InfoNote += "; UnfoldedLength=" + num2str(uL) + "; Units=" + num2str(Units) + "; Refolded=" + num2str(Refolded)
	InfoNote += "; LinkerLength=" + num2str(Linker) + "; ErrorInForce=" + num2str(Ferror)
	Note/K $Length
	Note $Length, InfoNote
	KillWaves/Z smoothed, B, realD, imagD, LClength, NoUnfold
End

//*******************************************************************************************************************************************************************
Function FC_P_Find(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	NVAR DisplayStart=root:FC_Analysis:FCDisplayStartNumber
	NVAR Temp = root:FC_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	String Forcewave, Lengthwave, Perswave, Contour
	SetDataFolder root:FC_Analysis:Fits:PersistenceData
	Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str(DisplayStart)
	Lengthwave = "root:FC_Analysis:Shift:shift_" + LengthName + num2str(DisplayStart)
	Perswave = "Persistence_Length" +  num2str(DisplayStart)
	Contour = "root:FC_Analysis:Fits:WLC:Contour" +  num2str(DisplayStart)	
	Duplicate/O $Lengthwave, Length
	Smooth/B 99, Length
	Duplicate/O $Forcewave, Force
	Force *= -1
	Smooth/B 99, Force		// first smooth, then cut
	Wave LClength = $Contour
	// calculate p via WLC using force and length:
	Duplicate/O Force, Persistence
	Persistence = kT/Force *( Length/LClength + 0.25 / (1-Length/LClength)^2 - 0.25 )
	Duplicate/O Persistence, $Perswave
	DoWindow/K Persistence_Length
	Display/W=(0,470,550,650)
	DoWindow/C Persistence_Length
	AppendToGraph $Perswave
	GetAxis/W=ForceClampAnalysis/Q bottom
	SetAxis left 0,1
	SetAxis bottom V_min, V_max
	ModifyGraph rgb($Perswave) = (19456,39168,0)
	Label bottom  "Time (\U)"
	Label left "Persistencelength p (nm)"
	ModifyGraph grid(left)=1
	ShowInfo
	KillWaves/Z Length, Force, Persistence
End

//*******************************************************************************************************************************************************************
Function FC_P_Cut(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayStart=root:FC_Analysis:FCDisplayStartNumber
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	String Forcewave, smForce, Perswave, Pcut, Info
	Variable starts, middle, ends
	Make/O/N=2 W_coef
	SetDataFolder root:FC_Analysis:Fits:PersistenceData
	Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str (DisplayStart)	
	Perswave = "Persistence_Length" +  num2str(DisplayStart)
	if (WaveExists($Perswave) == 0)
		DoAlert 0, "Get p first!"
		return 0
	endif
	smForce = ForceName + num2str (DisplayStart)	+ "_down_sm"
	Pcut = "Persistence_Length" +  num2str(DisplayStart) + "_down_cut"
	Duplicate/O $Forcewave, smoothed
	Smooth/B 79, smoothed
	Info = Note ($Forcewave)	
	starts = NumberByKey(" PullDuration", Info, "=") + 0.1
//	starts = 0.6
	middle = starts +  NumberByKey(" RampDownDuration", Info, "=")
	ends = middle + NumberByKey(" RelaxDuration", Info, "=") + NumberByKey(" RampUpDuration", Info, "=")// - 0.032
	// To find the exact middle, check where Smooth has its minimum
	WaveStats/M=1/Q/R=(middle - 0.3, middle + 0.3)/Z smoothed
	middle = V_maxloc	
	// Now find where protein ruptured off
	Differentiate smoothed/D=smoothed_DIF
	smoothed_DIF = abs(smoothed_DIF)
	FindLevel/Q/R=(middle, rightx(smoothed)) smoothed_DIF, 3000
	if (V_Flag == 0)
		ends = V_LevelX - 0.032	//0.032
	endif
	if (strlen(CsrInfo(B, "ForceClampAnalysis")) != 0)
		ends = xcsr(B, "ForceClampAnalysis")
	endif
//	Duplicate/O $Forcewave, smoothed
//	Smooth/B 29, smoothed
	CurveFit/N/Q line kwCWave=W_coef, $Forcewave(starts + 0.1,  middle - 0.1)	// fit ramp down
	Duplicate/O/R=(starts, middle) smoothed, $smForce	
	RemoveFromGraph/Z /W=ForceClampAnalysis $smForce
	AppendToGraph/W=ForceClampAnalysis/L=ForceAxis $smForce
	Wave force = $smForce	
	force = W_coef[0] + W_coef[1] * x
	force *= -1
	Duplicate/O/R=(starts, middle) $Perswave, $Pcut		
	DoWindow/K PvsF
	Display/W=(0,470,550,650)
	DoWindow/C PvsF
	AppendToGraph $Pcut vs $smForce
	ModifyGraph rgb($Pcut) = (19456,39168,0)	
	
	middle += NumberByKey(" RelaxDuration", Info, "=")
	smForce = ForceName + num2str (DisplayStart)	+ "_up_sm"
	Pcut = "Persistence_Length" +  num2str(DisplayStart) + "_up_cut"
	CurveFit/N/Q line kwCWave=W_coef, $Forcewave(middle + 0.1, ends - 0.1)		// fit ramp up
	Duplicate/O/R=(middle, ends) smoothed, $smForce	
	RemoveFromGraph/Z /W=ForceClampAnalysis $smForce
	AppendToGraph/W=ForceClampAnalysis/L=ForceAxis $smForce
	Wave force = $smForce
	force = W_coef[0] + W_coef[1] * x
	force *= -1	
	Duplicate/O/R=(middle, ends) $Perswave, $Pcut	
	AppendToGraph $Pcut vs $smForce
	ModifyGraph rgb($Pcut) = (26368,0,52224)
	Label bottom "Force (pN)"
	Label left "Persistencelength p (nm)"
	SetAxis left 0,2
	ModifyGraph grid(left)=1
	ShowInfo
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function FC_P_Plot(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	Variable i=0, k, binsize=1
	String Force, Pers, Forcebin, Persbin
	SetDataFolder root:FC_Analysis:Fits
	Wave GoodP
	SetDataFolder root:FC_Analysis:Fits:PersistenceData
	if (binsize > 1)
		DoWindow/K AllPvsForceBinned
		Display/W=(0,10,550,400) 
		DoWindow/C/F AllPvsForceBinned
	else
		DoWindow/K AllPvsForce
		Display/W=(0,10,550,400) 
		DoWindow/C/F AllPvsForce
	endif
	do
		Force = ForceName + num2str (GoodP[i])	+ "_up_sm"
		Pers = "Persistence_Length" + num2str(GoodP[i]) + "_up_cut"
		if (binsize > 1)
			Forcebin = ForceName + num2str (GoodP[i])	+ "_up_bin"
			Persbin = "Persistence_Length" + num2str(GoodP[i]) + "_up_bin"
			Make/O/N=1 $Forcebin, $Persbin
			Wave fbin=$Forcebin, pbin=$Persbin//, fsm=$Force, pcut=$Pers
			for (k = 0; k < ceil(numpnts($Force)/binsize); k += 1)
				Redimension/N=(k+1) $Forcebin, $Persbin
				WaveStats/Q/M=1/R=[k*binsize, (k+1)*binsize-1] $Force
				fbin[k] = V_avg
				WaveStats/Q/M=1/R=[k*binsize, (k+1)*binsize-1] $Pers
				pbin[k] = V_avg			
			endfor
			AppendToGraph $Persbin vs $Forcebin
			ModifyGraph rgb($Persbin)=(0,26112,0)
		else
			AppendToGraph $Pers vs $Force
			ModifyGraph rgb($Pers)=(0,26112,0)
		endif
		i += 1
	while (GoodP[i] != 0)
	Label left "Persistencelength (nm)"
	Label bottom "Force (pN)"
	ModifyGraph fSize=18//, mode=2
	SetAxis left 0,3.5 
	SetDataFolder root:FC_Analysis:Fits
	AppendToGraph P_Mean_Down vs Force_Mean_Down
	ModifyGraph lsize(P_Mean_Down)=1.5,  rgb(P_Mean_Down)=(65280,49152,16384)
End

//*******************************************************************************************************************************************************************
Function FC_P_Hist(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	String ForcewaveD, PerswaveD, Legends
	Variable Counter1=1, Counter2=1, Counter3=1, Counter4=1
	Variable Npoints, i=0, k, Bins, largest, sigma=1, binsize=0.05
	Variable F4=100, F3=50, F2=30, F1=10
	Variable RampFlag=0		// 0 for ramp-down, 1 for ramp-up
	SetDataFolder root:FC_Analysis:Fits
	Wave GoodP, SuccessP
	Make/O/N=1 List1, List2, List3, List4
	Make/O/N=1 List1s, List2s, List3s, List4s
	Make/O/N=1 List1Diff, List2Diff, List3Diff, List4Diff
	DoAlert 1, "Perform histograms for ramp-down (yes) or ramp-up (no)?"
	if (V_Flag == 2)
		RampFlag = 1
	endif
	Prompt F1, "Please enter 4 different force values:"; Prompt F2, ""; Prompt F3, ""; Prompt F4, "Force for reference p"
	DoPrompt "User Input", F1, F2, F3, F4
	if (V_Flag == 1)
		return 0
	endif
	Prompt sigma, "Enter sigma around force (pN):"; Prompt binsize, "Enter bin size for histogram (nm):"
	DoPrompt "User Input", sigma, binsize
	if (V_Flag == 1)
		return 0
	endif
	do
		if (RampFlag == 0)
			ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_down_sm"
			PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_down_cut"
		else
			ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_up_sm"
			PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_up_cut"
		endif
		Wave pwaved=$PerswaveD, fwaved=$ForcewaveD
		Npoints = numpnts(fwaved)
		for (k = 0; k < Npoints; k+=1)
			if (fwaved[k] >= (F1-sigma) && fwaved[k] <= (F1+sigma))
				Redimension/N=(Counter1) List1
				List1[Counter1-1] = pwaved[k]
				Counter1 += 1		
			elseif (fwaved[k] >= (F2-sigma) && fwaved[k] <= (F2+sigma))
				Redimension/N=(Counter2) List2
				List2[Counter2-1] = pwaved[k]
				Counter2 += 1				
			elseif (fwaved[k] >= (F3-sigma) && fwaved[k] <= (F3+sigma))
				Redimension/N=(Counter3) List3
				List3[Counter3-1] = pwaved[k]
				Counter3 += 1
			elseif (fwaved[k] >= (F4-sigma) && fwaved[k] <= (F4+sigma))
				Redimension/N=(Counter4) List4
				List4[Counter4-1] = pwaved[k]
				Counter4 += 1
			endif	
		endfor
		i += 1
	while (GoodP[i] != 0)
	WaveStats/M=1/Q List1		//find out which List has the largest value to determine number of bins for histograms
	Bins = V_max
	WaveStats/M=1/Q List2
	Bins = max(V_max, Bins)	
	WaveStats/M=1/Q List3
	Bins = max( V_max, Bins)	
	WaveStats/M=1/Q List4
	Bins = max( V_max, Bins)	
	Bins = ceil(Bins/binsize) + 2
	Make/O/N=(Bins) Hist1, Hist2, Hist3, Hist4
	Histogram/B={0, binsize, Bins} List1, Hist1; Histogram/B={0, binsize, Bins} List2, Hist2
	Histogram/B={0, binsize, Bins} List3, Hist3; Histogram/B={0, binsize, Bins} List4, Hist4
	// normalize above histograms by number of points in them
	Hist1 /= numpnts(List1); Hist2 /= numpnts(List2); Hist3 /= numpnts(List3); Hist4 /= numpnts(List4) 
	
	Make/O/N=(Bins) Hist1all, Hist2all, Hist3all, Hist4all	// histogram for failures and successes
	Histogram/B={0, binsize, Bins} List1, Hist1all; Histogram/B={0, binsize, Bins} List2, Hist2all
	Histogram/B={0, binsize, Bins} List3, Hist3all; Histogram/B={0, binsize, Bins} List4, Hist4all
	
	// now do the same for the successful folders
	if (SuccessP[1] != 0)
		i=0; Counter1=1; Counter2=1; Counter3=1; Counter4=1
		do
			if (RampFlag == 0)
			ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (SuccessP[i])	+ "_down_sm"
			PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(SuccessP[i]) + "_down_cut"
		else
			ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (SuccessP[i])	+ "_up_sm"
			PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(SuccessP[i]) + "_up_cut"
		endif
		Wave pwaved=$PerswaveD, fwaved=$ForcewaveD
			Npoints = numpnts(fwaved)
			for (k = 0; k < Npoints; k+=1)
				if (fwaved[k] >= (F1-sigma) && fwaved[k] <= (F1+sigma))
					Redimension/N=(Counter1) List1s
					List1s[Counter1-1] = pwaved[k]
					Counter1 += 1		
				elseif (fwaved[k] >= (F2-sigma) && fwaved[k] <= (F2+sigma))
					Redimension/N=(Counter2) List2s
					List2s[Counter2-1] = pwaved[k]
					Counter2 += 1				
				elseif (fwaved[k] >= (F3-sigma) && fwaved[k] <= (F3+sigma))
					Redimension/N=(Counter3) List3s
					List3s[Counter3-1] = pwaved[k]
					Counter3 += 1
				elseif (fwaved[k] >= (F4-sigma) && fwaved[k] <= (F4+sigma))
					Redimension/N=(Counter4) List4s
					List4s[Counter4-1] = pwaved[k]
					Counter4 += 1
				endif	
			endfor
			i += 1
		while (SuccessP[i] != 0)
	endif
	Histogram/A/B={0, binsize, Bins} List1s, Hist1all	// first accumulate into previous histograms
	Histogram/A/B={0, binsize, Bins} List2s, Hist2all
	Histogram/A/B={0, binsize, Bins} List3s, Hist3all
	Histogram/A/B={0, binsize, Bins} List4s, Hist4all
	WaveStats/M=1/Q List1s	//find out which List has the largest value to determine number of bins for histograms
	Bins = V_max
	WaveStats/M=1/Q List2s
	Bins = max(V_max, Bins)	
	WaveStats/M=1/Q List3s
	Bins = max( V_max, Bins)	
	WaveStats/M=1/Q List4s
	Bins = max( V_max, Bins)	
//	Bins = min(5, Bins)
//	Bins = 3.5
	Bins = ceil(Bins/binsize) + 2
	Make/O/N=(Bins) Hist1s, Hist2s, Hist3s, Hist4s
	Histogram/B={0, binsize, Bins} List1s, Hist1s; Histogram/B={0, binsize, Bins} List2s, Hist2s
	Histogram/B={0, binsize, Bins} List3s, Hist3s; Histogram/B={0, binsize, Bins} List4s, Hist4s	
	DoWindow/F PatFHistAll	// plot the histograms
	if (V_Flag == 0)
		Display/W=(0,10,400,400) Hist1all
		DoWindow/C/F PatFHistAll
		AppendToGraph Hist1s
		AppendToGraph/L=Force2 Hist2all, Hist2s
		AppendToGraph/L=Force3 Hist3all, Hist3s
		AppendToGraph/L=Force4 Hist4all, Hist4s
		ModifyGraph lblPos(left)=60,lblPos(Force2)=60,lblPos(Force3)=60, lblPos(Force4)=60
		ModifyGraph axisEnab(left)={0,0.23}, axisEnab(Force2)={0.25,0.48},axisEnab(Force3)={0.5,0.73}
		ModifyGraph axisEnab(Force4)={0.75,1}, freePos=0, mode=5, lsize=1.5, hbfill=5
		ModifyGraph rgb(Hist2all)=(16384,28160,65280), rgb(Hist3all)=(0,52224,0)
		ModifyGraph rgb(Hist4all)=(65280,43520,0)
		ModifyGraph rgb(Hist1s)=(39168,0,0), rgb(Hist2s)=(0,9472,39168)
		ModifyGraph rgb(Hist3s)=(0,26112,0), rgb(Hist4s)=(39168,26112,0)
		Label bottom "Persistencelength \f02p\f00 (nm)"		
	endif
	Legends = "\\s(Hist1all) at " + num2str(F1) + "pN (N=" + num2str(numpnts(List1) + numpnts(List0s)) + ")\r"
	Legends += "\\s(Hist2all) at " + num2str(F2) + "pN (N=" + num2str(numpnts(List2) + numpnts(List2s)) + ")\r"
	Legends += "\\s(Hist3all) at " + num2str(F3) + "pN (N=" + num2str(numpnts(List3) + numpnts(List3s)) + ")\r"
	Legends += "\\s(Hist4all) at " + num2str(F4) + "pN (N=" + num2str(numpnts(List4) + numpnts(List4s)) + ")\r"
	Legends += "         sigma = " + num2str(sigma)
	Legend/W=PatFHistAll/C/N=text0/F=0/M/H={0,4,8}/A=MT/Y=0.00 Legends
	//Plot only failure histograms
	DoWindow/F PatFHist		// plot the histograms
	if (V_Flag == 0)
		Display/W=(0,10,400,400) Hist1
		DoWindow/C/F PatFHist
		AppendToGraph/L=Force2 Hist2
		AppendToGraph/L=Force3 Hist3
		AppendToGraph/L=Force4 Hist4
		ModifyGraph lblPos(left)=60,lblPos(Force2)=60,lblPos(Force3)=60, lblPos(Force4)=60
		ModifyGraph axisEnab(left)={0,0.23}, axisEnab(Force2)={0.25,0.48},axisEnab(Force3)={0.5,0.73}
		ModifyGraph axisEnab(Force4)={0.75,1}, freePos=0, mode=5, lsize=1.5, hbfill=5
		ModifyGraph rgb(Hist2)=(16384,28160,65280), rgb(Hist3)=(0,52224,0)
		ModifyGraph rgb(Hist4)=(65280,43520,0), lowTrip=0.01
		Label bottom "Persistencelength \f02p\f00 (nm)"		
	endif
	Legends = "\\s(Hist1) at " + num2str(F1) + "pN (N=" + num2str(numpnts(List1) + numpnts(List0s)) + ")\r"
	Legends += "\\s(Hist2) at " + num2str(F2) + "pN (N=" + num2str(numpnts(List2) + numpnts(List2s)) + ")\r"
	Legends += "\\s(Hist3) at " + num2str(F3) + "pN (N=" + num2str(numpnts(List3) + numpnts(List3s)) + ")\r"
	Legends += "\\s(Hist4) at " + num2str(F4) + "pN (N=" + num2str(numpnts(List4) + numpnts(List4s)) + ")\r"
	Legends += "         sigma = " + num2str(sigma)
	Legend/W=PatFHist/C/N=text0/F=0/M/H={0,4,8}/A=MT/Y=0.00 Legends
	// alternatively, get average at each force, and then get change in p as force is lowered
	Variable Level1, Level2, force, referencep, counter=0
	i=0//; Counter1=0; Counter2=0; Counter3=0; Counter4=0
	do
		if (RampFlag == 0)
			ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_down_sm"
			PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_down_cut"
		else
			ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_up_sm"
			PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_up_cut"
		endif
		Wave pwaved=$PerswaveD, fwaved=$ForcewaveD
		Npoints = numpnts(fwaved)
		referencep = 0
		for (k = 3; k >= 0; k -= 1)
			if (k == 0)		
				force = F1
				Wave list = List1Diff
			elseif (k == 1)	
				force = F2
				Wave list = List2Diff
			elseif (k == 2)
				force = F3
				Wave list = List3Diff
			elseif (k == 3)
				force = F4
				Wave list = List4Diff	
			endif	
			WaveStats/Q/M=1/Z fwaved
			if ( (force - sigma) < V_min)		// check wether force-sigma is in range of forcewave
				Level1 = x2pnt(fwaved, V_minloc)
			elseif ( (force - sigma) > V_max)
				Level1 = x2pnt(fwaved, V_maxloc)
			else			
				FindLevel/P/Q/R=[x2pnt(fwaved, V_minloc), x2pnt(fwaved, V_maxloc)] fwaved, (force-sigma)
				Level1 = V_LevelX
			endif
			if ( (force + sigma) < V_min)	// check wether force+sigma is in range of forcewave
				Level2 = x2pnt(fwaved, V_minloc)
			elseif ( (force + sigma) > V_max)
				Level2 = x2pnt(fwaved, V_maxloc)
			else			
				FindLevel/P/Q/R=[Level1, x2pnt(fwaved, V_maxloc)] fwaved, (force+sigma)
				Level2 = V_LevelX
			endif
			WaveStats/M=1/Q/Z/R=[Level1, Level2] pwaved
			if (k == 3)
				if (Level1 != Level2)
					counter += 1
					Redimension/N=(counter) List1Diff, List2Diff, List3Diff, List4Diff
					referencep = V_avg
					list[counter-1] = V_avg -  referencep
				else
					referencep = 0
					break
				endif
			else
				if (Level1 == Level2)
					list[counter-1] = -1.4
				else
					list[counter-1] = V_avg -  referencep 
				endif
			endif
		endfor
		i += 1
	while (GoodP[i] != 0)
	Bins = 3.5/binsize
	Make/O/N=(Bins) Hist1Diff, Hist2Diff, Hist3Diff, Hist4Diff
	Histogram/B={-1.5, binsize, Bins} List1Diff, Hist1Diff; Histogram/B={-1.5, binsize, Bins} List2Diff, Hist2Diff
	Histogram/B={-1.5, binsize, Bins} List3Diff, Hist3Diff; Histogram/B={-1.5, binsize, Bins} List4Diff, Hist4Diff
	Hist1Diff /= counter; Hist2Diff /= counter; Hist3Diff /= counter; Hist4Diff /= counter	// normalize histograms
	DoWindow/F PDiffatFHist		// plot the histograms
	if (V_Flag == 0)
		Display/W=(0,10,400,400) Hist1Diff
		DoWindow/C/F PDiffatFHist
		AppendToGraph/L=Force2 Hist2Diff
		AppendToGraph/L=Force3 Hist3Diff
		AppendToGraph/L=Force4 Hist4Diff
		ModifyGraph lblPos(left)=60,lblPos(Force2)=60,lblPos(Force3)=60, lblPos(Force4)=60
		ModifyGraph axisEnab(left)={0,0.23}, axisEnab(Force2)={0.25,0.48},axisEnab(Force3)={0.5,0.73}
		ModifyGraph axisEnab(Force4)={0.75,1}, freePos=0, mode=5, lsize=1.5, hbfill=5
		ModifyGraph rgb(Hist2Diff)=(16384,28160,65280), rgb(Hist3Diff)=(0,52224,0)
		ModifyGraph rgb(Hist4Diff)=(65280,43520,0)
		Label bottom "\f02\F'Symbol'D\F'Arial'p\f00 (nm)"		
	endif
	Legends = "\\s(Hist1Diff) at " + num2str(F1) + "pN (N=" + num2str(counter) + ")\r"
	Legends += "\\s(Hist2Diff) at " + num2str(F2) + "pN (N=" + num2str(counter) + ")\r"
	Legends += "\\s(Hist3Diff) at " + num2str(F3) + "pN (N=" + num2str(counter) + ")\r"
	Legends += "\\s(Hist4Diff) at " + num2str(F4) + "pN (N=" + num2str(counter) + ")\r"
	Legends += "         sigma = " + num2str(sigma)
	Legend/W=PDiffatFHist/C/N=text0/F=0/M/H={0,4,8}/A=MT/Y=0.00 Legends
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function FC_xNorm(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	NVAR DisplayStart=root:FC_Analysis:FCDisplayStartNumber
	NVAR dL = root:FC_Analysis:Fits:WLC:ContourLengthIncrement
	NVAR pL = root:FC_Analysis:Fits:WLC:PersistenceLength
	NVAR Temp = root:FC_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	Variable i=0, starts, middle, ends, point, xvalue, B, realD, imagD, ratio
	String Forcewave, Lengthwave, normLength, smForce, Info, Step_Wave
	SetDataFolder root:FC_Analysis
	Wave Events
	SetDataFolder root:FC_Analysis:Steps
	Step_Wave = "StepStats_" + num2str(DisplayStart)
	Wave StepStats = $Step_Wave
	SetDataFolder root:FC_Analysis:Fits:xNormData
	Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str(DisplayStart)
	Lengthwave = "root:FC_Analysis:Shift:shift_" + LengthName + num2str(DisplayStart)
	normLength = "Norm_Length_down" + num2str(DisplayStart)
	smForce = ForceName + num2str (DisplayStart)	+ "_down_sm"
	
	// calculating x/Lc given F from the WLC requires inverting the equation - messy
	B = 100 * pL / kT - 0.75		// calculate ratio at 100 pN
	realD = real (( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3))	// real part
	imagD = imag (( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3))	// imaginary part
	ratio = 1/6 * ( 6 - realD + 2*B - 4*realD*B^2 / (realD^2 + imagD^2) )
	
	// first we have to fit a straight line to the appropriate portion of the force and cut that part out
	Duplicate/O $Forcewave, smoothed
	Smooth/B 79, smoothed
	Info = Note ($Forcewave)	
	starts = NumberByKey(" PullDuration", Info, "=") + 0.1
//	starts = 0.6
	middle = starts +  NumberByKey(" RampDownDuration", Info, "=")
	ends = middle + NumberByKey(" RelaxDuration", Info, "=") + NumberByKey(" RampUpDuration", Info, "=")// - 0.032
	// To find the exact middle, check where Smooth has its minimum
	WaveStats/M=1/Q/R=(middle - 0.3, middle + 0.3)/Z smoothed
	middle = V_maxloc	
	// Now find where protein ruptured off
	Differentiate smoothed /D=smoothed_DIF
	smoothed_DIF = abs(smoothed_DIF)
	FindLevel/Q/R=(middle, rightx(smoothed)) smoothed_DIF, 3000
	if (V_Flag == 0)
		ends = V_LevelX - 0.032	//0.032
	endif
	if (strlen(CsrInfo(B, "ForceClampAnalysis")) != 0)
		ends = xcsr(B, "ForceClampAnalysis")
	endif
	CurveFit/N/Q line $Forcewave(starts + 0.1,  middle - 0.1)	// fit ramp down
	Display $Forcewave
	DoUpdate
	Duplicate/O/R=(starts, middle) smoothed, $smForce	
	RemoveFromGraph/Z /W=ForceClampAnalysis $smForce
	AppendToGraph/W=ForceClampAnalysis/L=ForceAxis $smForce
	Wave force = $smForce, W_coef	
	force = W_coef[0] + W_coef[1] * x
	force *= -1
	
	Duplicate/D/O/R=(starts, middle) $Lengthwave, $normLength		// now cut length in same range
	Wave normL = $normLength	
	Smooth/B 59, normL		//99
	WaveStats/M=1/Q/R=[0,50] normL	
	//WaveStats/M=1/Q/R=[numpnts(normL),numpnts(normL)-50] normL	
	Duplicate/O normL, normFactor
	normFactor = V_avg	
	i = 1
	do
		xvalue = StepStats[i][0]
		if (xvalue > starts && xvalue < middle)		// an unfolding event happens during ramp
			point =  x2pnt(normL, xvalue)
			normFactor [point, numpnts(normFactor)-1] += dL * ratio		// at 100 pN extension is 83.5% of contour length
		endif
		i += 1
	while (i+1 < DimSize(StepStats, 0))	
	normL /= normFactor
	DoWindow/K xNormvsF
	Display/W=(0,470,550,650)
	DoWindow/C xNormvsF
	AppendToGraph $normLength vs $smForce
	ModifyGraph rgb($normLength) = (65280,21760,0)

	middle += NumberByKey(" RelaxDuration", Info, "=")
	normLength = "Norm_Length_up" + num2str(DisplayStart)
	smForce = ForceName + num2str (DisplayStart)	+ "_up_sm"
	CurveFit/N/Q line $Forcewave(middle + 0.1, ends - 0.1)		// fit ramp up
	Duplicate/O/R=(middle, ends) smoothed, $smForce	
	RemoveFromGraph/Z /W=ForceClampAnalysis $smForce
	AppendToGraph/W=ForceClampAnalysis/L=ForceAxis $smForce
	Wave force = $smForce
	force = W_coef[0] + W_coef[1] * x
	force *= -1	
		
	Duplicate/D/O/R=(middle, ends) $Lengthwave, $normLength		// now cut length in same range
	Wave normL = $normLength
	Smooth/B 59, normL		//99
	WaveStats/M=1/Q/R=[numpnts(normL),numpnts(normL)-50] normL	
	//WaveStats/M=1/Q/R=[0,50] normL
	Duplicate/O normL, normFactor
	normFactor = V_avg		
	i = 1
	do
		xvalue = StepStats[i][0]
		if (xvalue > middle && xvalue < ends)		// an unfolding event happens during ramp
			point =  x2pnt(normL, xvalue)
			normFactor [0, point] -= dL * ratio		// at 100 pN extension is 83.5% of contour length
		endif
		i += 1
	while (i+1 < DimSize(StepStats, 0))
	normL /= normFactor	
	AppendToGraph $normLength vs $smForce
	ModifyGraph rgb($normLength) = (26112,52224,0)
	SetAxis left, 0, 1.05
	Label bottom "Force (pN)"
	Label left "normalized Length"
	ShowInfo
	SetDataFolder root:Data
	KillWaves smoothed, smoothed_DIF, W_coef, normFactor
End

//*******************************************************************************************************************************************************************
Function FC_xnorm_Plot(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	Variable i=0, k
	Variable RampFlag=0			// 0 for ramp-down, 1 for ramp-up
	String Force, xNorm, Forcebin, xNormbin
	SetDataFolder root:FC_Analysis:Fits
	Wave GoodP
	SetDataFolder root:FC_Analysis:Fits:xNormData
	DoWindow/K AllxNormvsForce
	Display/W=(0,10,550,400) 
	DoWindow/C/F AllxNormvsForce
	DoAlert 1, "Perform histograms for ramp-down (yes) or ramp-up (no)?"
	if (V_Flag == 2)
		RampFlag = 1
	endif
	do
		if (RampFlag == 0)
			Force = ForceName + num2str (GoodP[i])	+ "_down_sm"
			xNorm = "Norm_Length_down" + num2str(GoodP[i])
		else
			Force = ForceName + num2str (GoodP[i]) + "_up_sm"
			xNorm = "Norm_Length_up" + num2str(GoodP[i])
		endif
		AppendToGraph $xNorm vs $Force
		ModifyGraph rgb($xNorm)=(16384,48896,65280)
		i += 1
	while (GoodP[i] != 0)
	Label left "Length/Length\B100pN"
	Label bottom "Force (pN)"
	ModifyGraph fSize=18
	SetAxis bottom 10, 100
	SetAxis left 0, 1.05
	
	DoAlert 1, "Do you want to include the successfull traces as well?"
	if(V_Flag == 2)
		return 0
	endif
	SetDataFolder root:FC_Analysis:Fits
	Wave SuccessP
	SetDataFolder root:FC_Analysis:Fits:xNormData
	i = 0
	do
		if (RampFlag == 0)
			Force = ForceName + num2str (SuccessP[i])	+ "_down_sm"
			xNorm = "Norm_Length_down" + num2str(SuccessP[i])
		else
			Force = ForceName + num2str (SuccessP[i]) + "_up_sm"
			xNorm = "Norm_Length_up" + num2str(SuccessP[i])
		endif
		AppendToGraph $xNorm vs $Force
		ModifyGraph rgb($xNorm)=(52224,0,0)
		i += 1
	while (SuccessP[i] != 0)	
End

//*******************************************************************************************************************************************************************
Function FC_xNorm_Hist(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	String Forcewave, xNormwave, Legends, InfoNote, HistName, ListName, DriftName
	Variable Counter=0, i=0, Bins, largest, sigma=0.4, binsize=0.04, F=12, from, to
	Variable RampFlag=0		// 0 for ramp-down, 1 for ramp-up
	SetDataFolder root:FC_Analysis:Fits
	Wave GoodP, SuccessP
	SetDataFolder root:FC_Analysis:Fits:xNormData
	Make/O/N=0 xNormListFail, DriftFail, xNormListFold, DriftFold
	DoAlert 1, "Perform histograms for ramp-down (yes) or ramp-up (no)?"
	if (V_Flag == 2)
		RampFlag = 1
	endif
	Prompt F, "Please enter the force value:"; Prompt sigma, "Enter sigma around force (pN):"; Prompt binsize, "Enter bin size for histogram (nm):"
	DoPrompt "User Input", F, sigma, binsize
	if (V_Flag == 1)
		return 0
	endif
	do
		if (RampFlag == 0)
			Forcewave = ForceName + num2str (GoodP[i])	+ "_down_sm"
			xNormwave = "Norm_Length_down" +  num2str(GoodP[i])
		else
			Forcewave = ForceName + num2str (GoodP[i])	+ "_up_sm"
			xNormwave = "Norm_Length_up" +  num2str(GoodP[i])
		endif
		Wave xwave=$xNormwave, fwave=$Forcewave
		FindLevel/P/Q fwave, (F-sigma)
		if (V_Flag == 0)			//level was found
			from = V_LevelX		// point number
			FindLevel/P/Q fwave, (F+sigma)
			if (V_Flag == 0)			//level was found
				to = V_LevelX		// point number
				Redimension/N=(Counter+1) xNormListFail, DriftFail
				WaveStats/Q/M=1/R=[from, to] xwave
				xNormListFail[Counter] =  V_avg
				InfoNote = note(fwave)	
				DriftFail[Counter-1] = NumberByKey(" ForceAfter(pN)", InfoNote, "=") - NumberByKey(" ForceBefore(pN)", InfoNote, "=")
				if (DriftFail[Counter-1] > -100)
				else
					DriftFail[Counter-1] = -100		// this is for wave that don't have the forces saved in their info
				endif	
				Counter += 1	
			endif
		endif		
		i += 1
	while (GoodP[i] != 0)

	i = 0; Counter=0
	do
		if (RampFlag == 0)
			Forcewave = ForceName + num2str (SuccessP[i])	+ "_down_sm"
			xNormwave = "Norm_Length_down" +  num2str(SuccessP[i])
		else
			Forcewave = ForceName + num2str (SuccessP[i])	+ "_up_sm"
			xNormwave = "Norm_Length_up" +  num2str(SuccessP[i])
		endif
		Wave xwave=$xNormwave, fwave=$Forcewave
		FindLevel/P/Q fwave, (F-sigma)
		if (V_Flag == 0)			//level was found
			from = V_LevelX		// point number
			FindLevel/P/Q fwave, (F+sigma)
			if (V_Flag == 0)			//level was found
				to = V_LevelX		// point number
				Redimension/N=(Counter+1) xNormListFold, DriftFold
				WaveStats/Q/M=1/R=[from, to] xwave
				xNormListFold[Counter] =  V_avg
				InfoNote = note(fwave)	
				DriftFold[Counter-1] = NumberByKey(" ForceAfter(pN)", InfoNote, "=") - NumberByKey(" ForceBefore(pN)", InfoNote, "=")
				if (DriftFold[Counter-1] > -100)
				else
					DriftFold[Counter-1] = -100		// this is for wave that don't have the forces saved in their info
				endif	
				Counter += 1	
			endif
		endif
		i += 1
	while (SuccessP[i] != 0)
	
	Bins = ceil(1.05/binsize) + 2
	Make/O/N=(Bins) xNormHistFail, xNormHistFold, xNormHistAll
	Histogram/B={0, binsize, Bins} xNormListFail, xNormHistFail		// histogram for failures
	Histogram/B={0, binsize, Bins} xNormListFold, xNormHistFold		// histogram for folders
	Histogram/B={0, binsize, Bins} xNormListFail, xNormHistAll
	Histogram/A/B={0, binsize, Bins} xNormListFold, xNormHistAll		// histogram for all	
	
	// copy failures
	ListName = "root:FC_Analysis:Fits:xNormList_Failures"
	DriftName = "root:FC_Analysis:Fits:Drift_Failures"
	HistName = "root:FC_Analysis:Fits:xNormHist_Failures"
	Duplicate/O xNormListFail, $ListName
	Duplicate/O DriftFail, $DriftName
	Duplicate/O xNormHistFail, $HistName	
	
	DoWindow/K xNormatFHist	// plot the histogram
	Display/W=(0,10,350,350) $HistName
	DoWindow/C/F xNormatFHist
	ModifyGraph rgb=(16384,48896,65280)
	DoWindow/K CollapsevsDrift	
	Display/W=(0,10,250,250) $ListName vs $DriftName	
	DoWindow/C/F CollapsevsDrift	
	ModifyGraph rgb=(16384,48896,65280)
	SetAxis bottom -45,45
	
	// copy folders
	ListName = "root:FC_Analysis:Fits:xNormList_Folders"
	DriftName = "root:FC_Analysis:Fits:Drift_Folders"
	HistName = "root:FC_Analysis:Fits:xNormHist_Folders"
	Duplicate/O xNormListFold, $ListName
	Duplicate/O DriftFold, $DriftName
	Duplicate/O xNormHistFold, $HistName		
	AppendToGraph/W=xNormatFHist $HistName
	AppendToGraph/W=CollapsevsDrift $ListName vs $DriftName	
	
	// copy all
	HistName = "root:FC_Analysis:Fits:xNormHist_All"
	Duplicate/O xNormHistAll, $HistName		
	
	ModifyGraph/W=xNormatFHist mode=5,hbFill=5
	Label/W=xNormatFHist bottom "L\BN"	
	Legends = "Force = " + num2str(F) + ", sigma = " + num2str(sigma) + "\r"
	Legends += num2str(numpnts(xNormListFail)) + "Failures\r"
	Legends += num2str(numpnts(xNormListFold)) + "Folders\r"
	Legend/W=xNormatFHist/C/N=text0/F=0/M/H={0,4,8}/X=0.00/A=LT/Y=0.00 Legends	
	Label/W=CollapsevsDrift left "L\BN"		
	Label/W=CollapsevsDrift bottom "Drift (pN)"	
	ModifyGraph/W=CollapsevsDrift mode=3,marker=19
	SetDataFolder root:Data
End


//*******************************************************************************************************************************************************************

//*******************************************************************************************************************************************************************
Function FC_UpdateWLC(ctrlName,varNum,varStr,varName) : SetVariableControl
	String ctrlName
	Variable varNum
	String varStr
	String varName
	FC_DisplayWLC()
End

//*******************************************************************************************************************************************************************
Function FC_ButtonWLC(ctrlName) : ButtonControl
	String ctrlName
	FC_DisplayWLC()
End

//*******************************************************************************************************************************************************************
Function FC_Traces_Cut(ctrlName) : ButtonControl
	String ctrlName
//	SVAR SourceFolder = root:FC_Analysis:SumTraces:SourceFolder
	SVAR DestFolder = root:FC_Analysis:SumTraces:DestinationFolder
	SVAR WaveNamePrefix	= root:FC_Analysis:SumTraces:AvgTracePrefix		
	String CutWave
	Variable delta, yoffset
//	if (DataFolderExists(SourceFolder) == 0)
//		DoAlert 0, "Source Data Folder does not exist!"
//		return 0
//	endif
	if (DataFolderExists(DestFolder) == 0)
		NewDataFolder $DestFolder
	endif
//	SetDataFolder $DestFolder
//	Wave W = $(SourceFolder + ":" + CsrWave(A))
	If(WaveExists(CsrWaveRef(A)))
	Wave W = CsrWaveRef(A)
	CutWave = DestFolder+":"+WaveNamePrefix + CsrWave(A)
	Duplicate/O/R=[pcsr(A),pcsr(B)] W, $CutWave
	Wave cut = $CutWave
	delta = deltax(cut)
	SetScale/P x, 0, delta, cut		// shift x scale (time) so that trace starts at zero
	yoffset = vcsr(A)
	cut -= yoffset					// shift so that wave starts at 0 length
	Else
		print "Which curve should I cut???"
		Beep
	EndIF
//	SetDataFolder $SourceFolder
End

//*******************************************************************************************************************************************************************
Function FC_Traces_Sum(ctrlName) : ButtonControl
	String ctrlName	
	NVAR FillUp		= root:FC_Analysis:FillUpFlag    //  Fill up the traces up to the end? yes=1,  No=0
	SVAR DestFolder	= root:FC_Analysis:SumTraces:DestinationFolder
//	SVAR SourceFolder		= root:FC_Analysis:SumTraces:SourceFolder
	SVAR WaveNamePrefix	= root:FC_Analysis:SumTraces:AvgTracePrefix	
	String List, intWaveName
	Variable i, j, N, NumWaves, MaxPoints=0, MaxScale=0, DeltaTime=Inf, point, Newpoints
	PauseUpdate
	SetDataFolder $DestFolder
	List = WaveList(WaveNamePrefix+"*", ";", "")
	NumWaves = ItemsInList(List)

	if (NumWaves == 0)
		Print "No waves in",DestFolder," with names starting with", WaveNamePrefix
		Beep
		return 0
	endif
	for (i = 0; i < NumWaves; i += 1)	// go through all waves to determine max length
		Wave cutWave = $(DestFolder+":"+StringFromList(i, List))	// get wave from list
		if (rightx(cutWave) > MaxScale)
			MaxScale = pnt2x(cutWave,numpnts(cutWave)-1)	// get the duration of the longest wave
		endif
		if (deltax(cutWave) < DeltaTime)
			DeltaTime = deltax(cutWave)	// get the smallest deltax of all waves
		endif
	endfor

	Variable NumberOfPoints = Round(MaxScale/DeltaTime)+1
	Make/O/N=(NumberOfPoints) Summed=0, Summed_std=0, Summed_count=0	
	SetScale/I x, 0, (MaxScale), "s", Summed, Summed_std, Summed_count

	DoWindow/K SummedTraces
	Display/W=(0,400,550,650)
	DoWindow/C SummedTraces
	AppendToGraph Summed	
	for (i = 0; i < NumWaves; i += 1)	// go through all waves
		Wave cutWave = $(DestFolder+":"+StringFromList(i, List))	// get wave from list
		if(deltax(cutWave)==deltax(Summed))
			N = numpnts(cutWave)
			Summed[0,N-1] += cutWave
		else
			N =Round(rightx(cutWave)/deltax(Summed))
			Interpolate2/N=(N)/Y=TempInterpolationWave cutWave
			Wave TempInterpolationWave
			Summed[0,N-1] += TempInterpolationWave
			
		endif
		if((FillUp)&&(N<NumberOfPoints))
			Summed[N,NumberOfPoints-1] += cutWave[N-1]
			Summed_count[N,NumberOfPoints-1]  +=1
		endif
		Summed_count[0,N-1] +=1
		PeriodicUpdate(2)
	endfor				
	Summed /= Summed_count	 // normalize by how many waves were added up
	Summed_std = 1/sqrt(Summed_count)
	ResumeUpdate
	Label/W=SummedTraces bottom,  "Time (\U)"
	Label/W=SummedTraces left, "Summed Length (nm), normalized by # of Waves"
	TextBox/W=SummedTraces/C/N=text0/F=0/B=1/A=LT "# of traces =" + num2str(NumWaves)
	ErrorBars/Y=1/W=SummedTraces Summed Y,wave=(Summed_std,Summed_std)
	KillWaves/Z TempInterpolationWave
End


//*******************************************************************************************************************************************************************
Function FC_DetectSteps(ctrlName) : ButtonControl // Detect step times and size. Created by Rodofo Hermans
	String ctrlName	
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	NVAR Noise = root:FC_Analysis:Steps:MinStep	// detect only steps that are larger than 5 nm
	NVAR Slide = root:FC_Analysis:Steps:SlideAverage
	NVAR Deviation = root:FC_Analysis:Steps:Deviation
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	Variable Npoints, from, to, average
	String Length_Wave, Step_Wave
	SetDataFolder root:FC_Analysis:Steps
	Length_Wave = "root:Data:" + LengthName + num2str(DisplayNo)
	Wave Length = $Length_Wave
	//Length_Wave = "shift_" + LengthName + num2str(DisplayNo)
	Step_Wave = "StepStats_" + num2str(DisplayNo)
	Make/O/N=(1,4) $Step_Wave = 0
	Wave StepStats = $Step_Wave
	SetDimLabel 1, 0, $("Time"), StepStats; SetDimLabel 1, 1, LengthBefore, StepStats
	SetDimLabel 1, 2, LengthAfter, StepStats; SetDimLabel 1, 3, StepSize, StepStats
	Npoints = numpnts(Length)
	from = 0
	if (strlen(CsrInfo(A, "ForceClampAnalysis")) > 0 && strlen(CsrInfo(B, "ForceClampAnalysis")) > 0)		
		//DoAlert 1, "Detect steps between cursors A and B?"
		//if (V_Flag == 2)
		//	SetDataFolder root:Data
		//	return 0
		//endif
		from = pcsr(A, "ForceClampAnalysis")//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate
		Npoints = pcsr(B, "ForceClampAnalysis")
	elseif (strlen(CsrInfo(A, "ForceClampAnalysis")) > 0)
		DoAlert 1, "Detect steps between cursor A and end of trace?"
		if (V_Flag == 2)
			SetDataFolder root:Data
			return 0
		endif
		from = pcsr(A, "ForceClampAnalysis")//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate
	elseif (strlen(CsrInfo(B, "ForceClampAnalysis")) > 0)
		DoAlert 1, "Detect steps between 0 and cursor B?"
		if (V_Flag == 2)
			SetDataFolder root:Data
			return 0
		endif
		Npoints = pcsr(B, "ForceClampAnalysis")	
	endif
	StepStats[(DimSize(StepStats, 0)-1)][0] = pnt2x(Length, from)		// record where the detection started (will be important for unfolding times)
	to = from + 10//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate	
	do				// go through each point in wave until you get to the end
		do				// go through each plateau
			WaveStats/M=1/Q/R=[from, to] Length
			to += 1//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
			if (abs(Length[to] - V_avg) > Noise)
				break		// is a step is detected break out of loop
			endif
		while((to+1) < Npoints)
		do 					// since to is likely sitting on slope of step-, go back a bit to find foot of step
			if ( (Length[to] - Length[to-1] ) < 0)
				break
			endif
			to -= 1
		while (to > from)
		if (to - from > 50)
			WaveStats/M=2/Q/R=[to - 50, to] Length
		else
			WaveStats/M=2/Q/R=[from, to] Length
		endif
		Redimension/N=(DimSize(StepStats, 0)+1, 4) StepStats
		StepStats[(DimSize(StepStats, 0)-1)][0] = pnt2x(Length, to)
		StepStats[(DimSize(StepStats, 0)-1)][1] = V_avg	
		// now perform sliding average over 10 points to see when step ends
		from = to//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate
		to += slide*2//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
		WaveStats/M=1/Q/R=[from, to] Length
		average = V_avg
		do
			from += slide//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate	
			to += slide//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
			WaveStats/M=1/Q/R=[from, to] Length
			if ( abs (average - V_avg) < Deviation)	// if step levelled off
				StepStats[(DimSize(StepStats, 0)-1)][2] = V_avg
				StepStats[(DimSize(StepStats, 0)-1)][3] = V_avg - StepStats[(DimSize(StepStats, 0)-1)][1]
				from += slide//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate	
				to += 1//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
				break
			elseif ((V_avg - StepStats[(DimSize(StepStats, 0)-1)][1]) > 500)	// if protein ruptured off
				StepStats[(DimSize(StepStats, 0)-1)][2] = V_avg
				StepStats[(DimSize(StepStats, 0)-1)][3] = V_avg - StepStats[(DimSize(StepStats, 0)-1)][1]
				FC_RedrawLines() 
				return 0
			endif
			average = V_avg
		while ((to+1) < Npoints)		
	while ((to+1) < Npoints)
	FC_RedrawLines() 
End

//*******************************************************************************************************************************************************************
Function FC_RedrawLines() 
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	String Step_Wave
	SetDataFolder root:FC_Analysis:Steps
	Step_Wave = "StepStats_" + num2str(DisplayNo)
	if (WaveExists($Step_Wave))		
		Wave StepStats = $Step_Wave
		RemoveFromGraph/Z/W=ForceClampAnalysis StepStats
		RemoveFromGraph/Z/W=ForceClampAnalysis StepStats
		DoUpdate	
		AppendToGraph/W=ForceClampAnalysis StepStats[][%LengthBefore] vs StepStats[][%Time]	
		AppendToGraph/W=ForceClampAnalysis StepStats[][%LengthAfter] vs StepStats[][%Time]			
		ModifyGraph/W=ForceClampAnalysis mode($Step_Wave)=3,rgb($Step_Wave)=(0,0,0)
		ModifyGraph/W=ForceClampAnalysis marker($Step_Wave)=19, msize($Step_Wave)=2.5
		Step_Wave += "#1"			
		ModifyGraph/W=ForceClampAnalysis mode($Step_Wave)=3,rgb($Step_Wave)=(0,0,0)
		ModifyGraph/W=ForceClampAnalysis marker($Step_Wave)=19, msize($Step_Wave)=2.5
	endif
	DoUpdate
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function FC_AddStep(ctrlName) : ButtonControl // Manually add step event
	String ctrlName	
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	NVAR Noise = root:FC_Analysis:Steps:MinStep		// detect only steps that are larger than 5 nm
	NVAR Slide = root:FC_Analysis:Steps:SlideAverage
	NVAR Deviation = root:FC_Analysis:Steps:Deviation
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	Variable Npoints, from, to, average, i=0
	String Length_Wave, Step_Wave
	if (strlen(CsrInfo(A, "ForceClampAnalysis")) == 0)
		DoAlert 0, "Place cursor A on trace"
		return 0
	endif
	SetDataFolder root:FC_Analysis:Steps
	Length_Wave = "root:FC_Analysis:Shift:shift_" + LengthName + num2str(DisplayNo)
	Wave Length = $Length_Wave
	Length_Wave = "shift_" + LengthName + num2str(DisplayNo)
	Step_Wave = "StepStats_" + num2str(DisplayNo)
	if ( ! WaveExists($Step_Wave))
		Make/O/N=(0,4) $Step_Wave
		SetDimLabel 1, 0, $("Time"), $Step_Wave; SetDimLabel 1, 1, LengthBefore, $Step_Wave
		SetDimLabel 1, 2, LengthAfter, $Step_Wave; SetDimLabel 1, 3, StepSize, $Step_Wave
	endif
	Wave StepStats = $Step_Wave	
	Npoints = numpnts(Length)
	to = pcsr(A, "ForceClampAnalysis")	
	if (pnt2x(Length, to) > StepStats[DimSize(StepStats,0)-1][%Time])	// if new point is at end
		i = DimSize(StepStats,0)
		Redimension/N=(i+1, -1) StepStats
		StepStats[i][0] = pnt2x(Length, to)		
	else	
		do				// figure out where to insert new step in StepStats Wave
			if (pnt2x(Length, to) < StepStats[i][%Time])
				InsertPoints i, 1, StepStats
				StepStats[i][0] = pnt2x(Length, to)
				break
			endif
			i += 1
		while (i < (DimSize(StepStats, 0)-1))
	endif
	WaveStats/M=1/Q/R=[to - 8, to] Length
	StepStats[i][1] = V_avg
	// now perform sliding average over "slide" points to see when step ends	
	from = to
	to += slide*2
	WaveStats/M=1/Q/R=[from, to] Length
	average = V_avg
	do
		from += slide
		to += slide
		WaveStats/M=1/Q/R=[from, to] Length
		if ( abs (average - V_avg) < Deviation)	// if step levelled off
			if (pnt2x(Length, to) > StepStats[i+1][%Time] && DimSize(StepStats, 0) > (i+1))		// this is important for fast unfolding staircases
				StepStats[i][2] = StepStats[i+1][%LengthBefore]
			else
				StepStats[i][2] = V_avg
			endif
			StepStats[i][3] = StepStats[i][%LengthAfter] - StepStats[i][%LengthBefore]
			break
		endif
		average = V_avg
	while ((to+1) < Npoints)		
	FC_RedrawLines() 
End

//*******************************************************************************************************************************************************************
Function FC_DeleteStep(ctrlName) : ButtonControl // Manually delete step event
	String ctrlName	
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	Variable point
	String Step_Wave
	SetDataFolder root:FC_Analysis:Steps
	Step_Wave = "StepStats_" + num2str(DisplayNo)
	if (strlen(CsrInfo(A, "ForceClampAnalysis")) == 0 || stringmatch (CsrWave(A, "ForceClampAnalysis"), Step_Wave) == 0 )
		DoAlert 0, "Place cursor A on StepStats"
		return 0
	endif	
	point = pcsr(A, "ForceClampAnalysis")
	DeletePoints (point), 1, $Step_Wave
	FC_RedrawLines() 
	Cursor/A=1/P/W=ForceClampAnalysis A $Step_Wave, point
End

//*******************************************************************************************************************************************************************
Function FC_DeleteAllSteps(ctrlName) : ButtonControl 	// Delete wave with step events
	String ctrlName	
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	String Step_Wave
	SetDataFolder root:FC_Analysis:Steps
	Step_Wave = "StepStats_" + num2str(DisplayNo)
	RemoveFromGraph/Z/W=ForceClampAnalysis $Step_Wave
	RemoveFromGraph/Z/W=ForceClampAnalysis $Step_Wave
	KillWaves $Step_Wave
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function FC_CompileUnfoldingTimes(ctrlName) : ButtonControl	// compile all unfolding times
	String ctrlName	
	Variable NumWaves, i, Nsteps, Trace, columns
	String Step_Wave, List
	SetDataFolder root:FC_Analysis:Steps
	List = WaveList("StepStats_*", ";", "")
	NumWaves = ItemsInList(List)
	if (NumWaves==0)
		DoAlert 0, "There are no StepStats waves!"
		SetDataFolder root:Data
		return 0
	endif
	Make/O/N=(0, 0) UnfoldingTimes
	for (i = 0; i < NumWaves; i += 1)	
		Step_Wave = StringFromList(i, List)				// get wave from list
		Wave StepStats = $Step_Wave		
		Nsteps = DimSize(StepStats, 0)-3
		columns = max (DimSize(UnfoldingTimes, 1), Nsteps)
		Trace = str2num(StringByKey("StepStats",Step_Wave, "_" ))
		Redimension/N=(Trace+1,columns) UnfoldingTimes
		UnfoldingTimes[Trace][0,Nsteps] = StepStats[q+1][0] - StepStats[0][0]		// calculate unfolding time
	endfor
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function FC_CompileStepHeights(ctrlName) : ButtonControl	// compile all stepheights
	String ctrlName	
	Variable NumWaves, i, Nsteps, Binstart, Binwidth = 0.3, Numbins
	String List
	SetDataFolder root:FC_Analysis:Steps
	List = WaveList("StepStats_*", ";", "")
	NumWaves = ItemsInList(List)
	if (NumWaves<0)
		DoAlert 0, "There are no StepStats waves!"
		SetDataFolder root:Data
		return 0
	endif
	Make/O/N=0 StepHeights
	for (i = 0; i < NumWaves; i += 1)	
		Wave StepStats = $(StringFromList(i, List))		// get wave from list
		Nsteps = DimSize(StepStats, 0)-2		// exclude first and last entry
		Redimension/N=(numpnts(StepHeights)+Nsteps) StepHeights
		StepHeights[numpnts(StepHeights)-Nsteps, numpnts(StepHeights) - 1] = StepStats[p-(numpnts(StepHeights)-Nsteps)+1][3]
	endfor
	WaveStats/M=1/Q StepHeights
	Binstart = floor(V_min)-5
	Prompt Binwidth, "Please enter width of bins (nm)"
	DoPrompt "Step height histogram", Binwidth
	Numbins = ceil((ceil(V_max) + 5 - Binstart) / Binwidth)
	Make/O/N=(Numbins) StepHeightHistogram
	Histogram/B={Binstart, Binwidth, Numbins} StepHeights, StepHeightHistogram
	DoWindow StepHeight_Histogram
	if (V_Flag == 1)
		RemoveFromGraph/W=StepHeight_Histogram StepHeightHistogram
	else
		Display/W=(550,500,850,700)
		DoWindow/C StepHeight_Histogram
	endif
	AppendToGraph/W=StepHeight_Histogram StepHeightHistogram
	ModifyGraph/W=StepHeight_Histogram mode=5,hbFill=5, rgb=(0,39168,19712)
	Label bottom "Step Height (nm)"
	Label left "# Occurrences"
	TextBox/W=StepHeight_Histogram/C/N=text4/F=0/B=1/A=LT "# of Events =" + num2str(numpnts(StepHeights))
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function AddInfoStamp()
	String Infotext = ""
	TextBox/K/N=GraphInfo
	pathinfo home
	Infotext = "\F'Courier New'\Z07"+S_path + IgorInfo(1)+":"+WinName(0,1)+"\r"+TraceNameList("",";",1)
	TextBox/C/N=GraphInfo/F=0/B=1/E=2/A=LB/X=0.00/Y=0.00  Infotext
End

//********************************************************* Summary of all function used *********************************************************************

//General Functions:

//InitializeA()
//AFMAnalysisPanel()
//Analysisdisableproc(name,tab)
//DetectWavenames()
//LabelFitParamMatrix()
//LoadFilters()
//PeriodicUpdate(T)
//KeyboardPanelHook(s)

// All functions for FX*******************************************************************************************
//Display_FXUncorrected(ctrlName,checked) : CheckBoxControl
//Display_FX_Recordings(ctrlName,varNum,varStr,varName) : SetVariableControl
//KillFXAnalysisGraph(ctrlName) : ButtonControl

//FX_CorrectAll(ctrlName) : ButtonControl
//FX_CorrectOne(ctrlName) : ButtonControl

//FX_Baseline(ctrlName) : ButtonControl
//FX_SetElasticityModel(ctrlName,popNum,popStr) : PopupMenuControl	
//FX_LoadParameters()
//FX_ModelDisplay()
//FX_UpdateFits(ctrlName) : ButtonControl
//FX_CallUpdate(ctrlName,varNum,varStr,varName) : SetVariableControl
//FX_CheckTag(ctrlName,checked) : CheckBoxControl
//FX_SelectFit(ctrlName,popNum,popStr) : PopupMenuControl	
		
	//FitWLCToCursor()
	//FitWLCSeToCursor()
	//FitFJCToCursor()
	//FitFJCSeToCursor()
	//FitFRCToCursor()
	//FitFRCSeToCursor()
	//FitTCToCursor()
		
	//FitWLCToAandB()
	//FitFJCToAandB()
	//FitFJCSeToAandB()
		
	//FX_DisplayWLC()
	//FX_DisplayFJC()
	//FX_DisplayFJCSe()
	//FX_DisplayWLCSe()
	//FX_DisplayLidavaru()
	//FX_DisplayLidavaruSe()
	//FX_DisplayTC()
		
	//SetP(name, value, event)
	//SetL(name, value, event)
	//SetSe(name, value, event)
	//SetAngle(name, value, event)
	//SetThickness(name, value, event)	
	//SetSeparation(name, value, event)	
	
//FX_FitEachPeak(ctrlName,checked) : CheckBoxControl
//FX_ClearFits(ctrlName) : ButtonControl

//FX_DisplayEachWLC()
//FX_DisplayEachWLCSe()
//FX_DisplayEachFJC()
//FX_DisplayEachFJCSe()
//FX_DisplayEachLidavaru()
//FX_DisplayEachLidavaruSe()
//FX_DisplayEachTC()

//FX_GetWaveTraceOffset(graphName, w)
//LVFitWLC(w,x) : FitFunc
//LVFitFJC(w,F) : FitFunc
//LVFitFJCSe(w,F) : FitFunc											

//FX_DeleteWaves(ctrlName) : ButtonControl
//FX_FindPeaksForward(ctrlName) : ButtonControl
//FX_FindPeaksBackward(ctrlName) : ButtonControl
//FX_EnterValues(ctrlName) : ButtonControl
//FX_Histp(ctrlName) : ButtonControl
//FX_HistL(ctrlName) : ButtonControl
//FX_HistDelta(ctrlName) : ButtonControl
//FX_HistForces(ctrlName) : ButtonControl
//FX_pvsF(ctrlName) : ButtonControl


// All functions for FC ************************************************************************************
//Display_FCUncorrected(ctrlName,checked) : CheckBoxControl
//FC_UpdatePlot(ctrlName,varNum,varStr,varName) : SetVariableControl	
//Display_FC_Recordings()	
//KillFCAnalysisGraph(ctrlName) : ButtonControl
//FC_Export(ctrlName) : ButtonControl
//FCImportWaves()

//FC_CorrectAll(ctrlName) : ButtonControl
//FC_CorrectOne(ctrlName) : ButtonControl
//FC_DeleteWaves(ctrlName) : ButtonControl	

//FC_DisplayWLC()
//FC_P_Find(ctrlName) : ButtonControl
//FC_P_Cut(ctrlName) : ButtonControl	
//FC_P_Hist(ctrlName) : ButtonControl
//FC_xNorm(ctrlName) : ButtonControl
//FC_xNorm_Hist(ctrlName) : ButtonControl

//FC_UpdateWLC(ctrlName,varNum,varStr,varName) : SetVariableControl
//FC_ButtonWLC(ctrlName) : ButtonControl		

//FC_Traces_Cut(ctrlName) : ButtonControl
//FC_Traces_Sum(ctrlName) : ButtonControl	

//FC_DetectSteps(ctrlName) : ButtonControl
//FC_RedrawLines() 
//FC_AddStep(ctrlName) : ButtonControl
//FC_DeleteStep(ctrlName) : ButtonControl
//FC_DeleteAllSteps(ctrlName) : ButtonControl 
//FC_CompileUnfoldingTimes(ctrlName) : ButtonControl
//FC_CompileStepHeights(ctrlName) : ButtonControl	

//AddInfoStamp()


//*******************************************************************************************************************************************************************
Function FC_P_Mean(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	String ForcewaveU, PerswaveU, ForcewaveD, PerswaveD, Forcewave
	Variable i = 0, Npoints, binstart=0, binwidth=0.25, k, bin, m, StepFlag, xvalue1, xvalue2
	SetDataFolder root:FC_Analysis:Fits
	Wave GoodP
	Wave Events=$"root:FC_Analysis:Events"
	Make/O/N=800 P_Mean_Down=0, Force_Mean_Down=0, P_Variance_Down=0, Countwave_Down=0, Stdev_Down_A, Stdev_Down_B
	Make/O/N=800 P_Mean_Up=0, Force_Mean_Up=0, P_Variance_Up=0, Countwave_Up=0, Stdev_Up_A, Stdev_Up_B 
	Make/O/N=1600 Stdev_Down, ForceStdev_Down, Stdev_Up, ForceStdev_Up
	Make/O/N=800 P_Mean_Tot=0, Force_Mean_Tot=0, P_Variance_Tot=0, Countwave_Tot=0
	do		// go through each wave
		Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str (GoodP[i])	
		ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_down_sm"
		PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_down_cut"
		ForcewaveU = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_up_sm"
		PerswaveU = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_up_cut"
		Wave pwaved=$PerswaveD, fwaved=$ForcewaveD
		Wave pwaveu=$PerswaveU, fwaveu=$ForcewaveU
		Npoints = numpnts(fwaved)
		for (k = 0; k < Npoints; k+=1)		// loop through each point in wave
			m = 0
			StepFlag = 0
			do 	// make sure that k is not where a unit unfolded
				xvalue1 = pnt2x( $Forcewave, Events[GoodP[i]][m])
				xvalue2 = pnt2x(fwaved, k)
				if ( abs (xvalue1 - xvalue2) < 0.02)
					StepFlag = 1		// if point is in vicinity (0.02) of unfolding event, discard it
				endif
				m += 1
			while (Events[GoodP[i]][m] != 0 && StepFlag == 0 && xvalue1<xvalue2)
			if (StepFlag == 0)		// if point is not in vicinity of unfolding event, take it
				bin = round ((fwaved[k] - binstart)/binwidth)		// gives right bin				
				P_Mean_Down[bin] += pwaved[k]
				Force_Mean_Down[bin] += fwaved[k]
				Countwave_Down[bin] += 1
				P_Mean_Tot[bin] += pwaved[k]
				Force_Mean_Tot[bin] += fwaved[k]
				Countwave_Tot[bin] += 1
			endif
		endfor
		Npoints = numpnts(fwaveu)
		for (k = 0; k < Npoints; k+=1)
			m = 0
			StepFlag = 0
			do 	// make sure that k is not where a unit unfolded
				xvalue1 = pnt2x( $Forcewave, Events[GoodP[i]][m])
				xvalue2 = pnt2x(fwaveu, k)
				if ( abs (xvalue1 - xvalue2) < 0.02)
					StepFlag = 1		// if point is in vicinity (0.02) of unfolding event, discard it
				endif
				m += 1
			while (Events[GoodP[i]][m] != 0 && StepFlag == 0 && xvalue1<xvalue2)
			if (StepFlag == 0)		// if point is not in vicinity of unfolding event, take it
				bin = round ((fwaveu[k] - binstart)/binwidth)		// gives right bin				
				P_Mean_Up[bin] += pwaveu[k]
				Force_Mean_Up[bin] += fwaveu[k]
				Countwave_Up[bin] += 1
				P_Mean_Tot[bin] += pwaveu[k]
				Force_Mean_Tot[bin] += fwaveu[k]
				Countwave_Tot[bin] += 1
			endif
		endfor
		i += 1
	while (GoodP[i] != 0)
	Npoints = numpnts(P_Mean_Down)
	for (k = 0; k < Npoints; k += 1)
		P_Mean_Down[k] /= Countwave_Down[k]
		Force_Mean_Down[k] /= Countwave_Down[k]
	endfor
	Npoints = numpnts(P_Mean_Up)
	for (k = 0; k < Npoints; k += 1)
		P_Mean_Up[k] /= Countwave_Up[k]
		Force_Mean_Up[k] /= Countwave_Up[k]
	endfor
	Npoints = numpnts(P_Mean_Tot)
	for (k = 0; k < Npoints; k += 1)
		P_Mean_Tot[k] /= Countwave_Tot[k]
		Force_Mean_Tot[k] /= Countwave_Tot[k]
	endfor
	// Now that we have the mean, we can compute the standard deviation (root of variace)
	i = 0
	do
		Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str (GoodP[i])	
		ForcewaveD = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_down_sm"
		PerswaveD = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_down_cut"
		ForcewaveU = "root:FC_Analysis:Fits:PersistenceData:" + ForceName + num2str (GoodP[i])	+ "_up_sm"
		PerswaveU = "root:FC_Analysis:Fits:PersistenceData:Persistence_Length" +  num2str(GoodP[i]) + "_up_cut"
		Wave pwaved=$PerswaveD, fwaved=$ForcewaveD
		Wave pwaveu=$PerswaveU, fwaveu=$ForcewaveU
		Npoints = numpnts(pwaved)
		for (k = 0; k < Npoints; k+=1)
			m = 0
			StepFlag = 0
			do 	// make sure that k is not where a unit unfolded
				xvalue1 = pnt2x( $Forcewave, Events[GoodP[i]][m])
				xvalue2 = pnt2x(fwaved, k)
				if ( abs (xvalue1 - xvalue2) < 0.02)
					StepFlag = 1		// if point is in vicinity (0.02) of unfolding event, discard it
				endif
				m += 1
			while (Events[GoodP[i]][m] != 0 && StepFlag == 0 && xvalue1<xvalue2)
			if (StepFlag == 0)		// if point is not in vicinity of unfolding event, take it
				bin = round ((fwaved[k] - binstart)/binwidth)		// gives right bin				
				P_Variance_Down[bin] += (pwaved[k] - P_Mean_Down[bin])^2
				Countwave_Down[bin] += 1
				P_Variance_Tot[bin] += (pwaved[k] - P_Mean_Tot[bin])^2
				Countwave_Tot[bin] += 1
			endif
		endfor
		Npoints = numpnts(pwaveu)
		for (k = 0; k < Npoints; k+=1)
			m = 0
			StepFlag = 0
			do 	// make sure that k is not where a unit unfolded
				xvalue1 = pnt2x( $Forcewave, Events[GoodP[i]][m])
				xvalue2 = pnt2x(fwaveu, k)
				if ( abs (xvalue1 - xvalue2) < 0.02)
					StepFlag = 1		// if point is in vicinity (0.02) of unfolding event, discard it
				endif
				m += 1
			while (Events[GoodP[i]][m] != 0 && StepFlag == 0 && xvalue1<xvalue2)
			if (StepFlag == 0)		// if point is not in vicinity of unfolding event, take it
				bin = round ((fwaveu[k] - binstart)/binwidth)		// gives right bin				
				P_Variance_Up[bin] += (pwaveu[k] - P_Mean_Up[bin])^2
				Countwave_Up[bin] += 1
				P_Variance_Tot[bin] += (pwaveu[k] - P_Mean_Tot[bin])^2
				Countwave_Tot[bin] += 1
			endif
		endfor
		i += 1
	while (GoodP[i] != 0)
	Npoints = numpnts(P_Mean_Down)
	for (k = 0; k < Npoints; k += 1)
		P_Variance_Down[k] /= Countwave_Down[k]
	endfor
	Npoints = numpnts(P_Mean_Up)
	for (k = 0; k < Npoints; k += 1)
		P_Variance_Up[k] /= Countwave_Up[k]
	endfor
	Npoints = numpnts(P_Mean_Tot)
	for (k = 0; k < Npoints; k += 1)
		P_Variance_Tot[k] /= Countwave_Tot[k]
	endfor
	Stdev_Down_A = P_Mean_Down + sqrt(P_Variance_Down)
	Stdev_Down_B = P_Mean_Down - sqrt(P_Variance_Down)
	Stdev_Up_A = P_Mean_Up + sqrt(P_Variance_Up)
	Stdev_Up_B = P_Mean_Up - sqrt(P_Variance_Up)
	Npoints = numpnts(P_Mean_Down)
	for (k = 0; k < Npoints; k += 1)
		Stdev_Down[2*k] = Stdev_Down_A[k]
		Stdev_Down[2*k+1] = Stdev_Down_B[k]
		ForceStdev_Down[2*k] = Force_Mean_Down[k]
		ForceStdev_Down[2*k+1] = Force_Mean_Down[k]
	endfor
	Npoints = numpnts(P_Mean_Up)
	for (k = 0; k < Npoints; k += 1)
		Stdev_Up[2*k] = Stdev_Up_A[k]
		Stdev_Up[2*k+1] = Stdev_Up_B[k]
		ForceStdev_Up[2*k] = Force_Mean_Up[k]
		ForceStdev_Up[2*k+1] = Force_Mean_Up[k]
	endfor
	DoWindow MeanPvsForce
	if (V_Flag == 0)
		Display/W=(0,10,550,400) Stdev_Up_A, Stdev_Up_B vs Force_Mean_Up
		DoWindow/C/F MeanPvsForce
		AppendToGraph Stdev_Up vs ForceStdev_Up
		AppendToGraph P_Mean_Up vs Force_Mean_Up
		AppendToGraph Stdev_Down_A, Stdev_Down_B vs Force_Mean_Up
		AppendToGraph Stdev_Down vs ForceStdev_Down
		AppendToGraph P_Mean_Down vs Force_Mean_Down
		ModifyGraph rgb(Stdev_Up_A) = (48896,59904,65280), rgb(Stdev_Up_B) = (48896,59904,65280)
		ModifyGraph rgb(Stdev_Up) = (48896,59904,65280), rgb(P_Mean_Up) = (0,12800,52224)
		ModifyGraph rgb(Stdev_Down_A) = (65280,48896,48896), rgb(Stdev_Down_B) = (65280,48896,48896)
		ModifyGraph rgb(Stdev_Down) = (65280,48896,48896)
		ModifyGraph lstyle(Stdev_Up)=1, lstyle(Stdev_Down)=1, lsize(P_Mean_Up)=2, lsize(P_Mean_Down)=2
		ModifyGraph lsize(Stdev_Up)=0.75,lsize(Stdev_Down)=0.75
		Label bottom "Force (pN)"
		Label left "Persistencelength p (nm)"
		SetAxis left 0,1.2
		ShowInfo		
	endif
	KillWaves Countwave_Down, Countwave_Up, Countwave_Tot
	SetDataFolder root:Data
End

//*******************************************************************************************************************************************************************
Function FC_Lc_Find(ctrlName) : ButtonControl
	String ctrlName
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	NVAR DisplayStart=root:FC_Analysis:FCDisplayStartNumber
	NVAR pL = root:FC_Analysis:Fits:WLC:PersistenceLength
	NVAR uL = root:FC_Analysis:Fits:WLC:FoldedLength	
	NVAR Linker = root:FC_Analysis:Fits:WLC:Linker
	NVAR Units = root:FC_Analysis:Fits:WLC:Units
	NVAR Temp = root:FC_Analysis:Temperature	
	Variable kT = 1.380658*(273+Temp) / 100
	String Forcewave, Lengthwave, Contour, UnfoldedWave
	SetDataFolder root:FC_Analysis
	Wave Events
	SetDataFolder root:FC_Analysis:Fits:ContourData
	Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str(DisplayStart)
	Lengthwave = "root:FC_Analysis:Shift:shift_" + LengthName + num2str(DisplayStart)
	Contour = "Contour_Length_Unit" +  num2str(DisplayStart)	
	UnfoldedWave = "root:FC_Analysis:Fits:WLC:UnfoldedUnits" + num2str (DisplayStart)
	Duplicate/D/O $Lengthwave, Length
	Smooth/B 199, Length
	Duplicate/D/O $Forcewave, Force
	Force *= -1
	Smooth/B 199, Force		// first smooth, then cut
	Make/O/D/N=(numpnts(Force)) B, realD, imagD, LcWave
	SetScale/P x, pnt2x(Force, 0), deltax(Force), LcWave
	// calculating x/LC given F from the WLC requires inverting the equation - messy
	// x/LC = 1/6 * ( 6 - D + 2*B - 4*B^2 /D)
	//    = 1/6 * ( 6 - realD + 2*B - 4*realD*B^2 / (realD^2 + imagD^2) )
	// B = F * p / kT - 0.75
	// D = ( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3)
	B = Force * pL / kT - 0.75
	realD = real (( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3))	// real part
	imagD = imag (( 27 - 8*B^3 + 3* sqrt(81 - 48*B^3) )^(1/3))	// imaginary part
	LcWave = Length * 6 / ( 6 - realD + 2*B - 4*realD*B^2 / (realD^2 + imagD^2) )
	// now subtract linker and baselength of monomers from LcWave
	LcWave -= Linker// + uL * Units
	// now divide by the number of unfolded units
	Wave unfolded = $UnfoldedWave
	Duplicate/O LcWave, $Contour

	DoWindow/K Contour_Length
	Display/W=(0,470,550,650)
	DoWindow/C Contour_Length
	AppendToGraph $Contour
	GetAxis/W=ForceClampAnalysis/Q bottom
	SetAxis bottom V_min, V_max
	SetAxis left 0, 40
	ModifyGraph rgb($Contour) = (0,52224,52224)
	Label bottom  "Time (\U)"
	Label left "Contourlength Lc (nm)"
	ModifyGraph grid(left)=1
	ShowInfo
	KillWaves/Z Length, Force, B, realD, imagD//, LcWave
End

//*******************************************************************************************************************************************************************
Function FC_Lc_Cut(ctrlName) : ButtonControl
	String ctrlName
	NVAR DisplayStart=root:FC_Analysis:FCDisplayStartNumber
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	String Forcewave, smForce, Lcwave, Lccut, Info
	Variable starts, middle, ends
	SetDataFolder root:FC_Analysis:Fits:ContourData
	Forcewave = "root:FC_Analysis:Shift:filtered_" + ForceName + num2str (DisplayStart)	
	LcWave = "Contour_Length_Unit" +  num2str(DisplayStart)	
	smForce = ForceName + num2str (DisplayStart)	+ "_down_sm_Lc"
	Lccut = "Contour_Length" +  num2str(DisplayStart) + "_down_cut"
	Info = Note ($Forcewave)	
	starts = NumberByKey(" PullDuration", Info, "=") + 0.1	// push at 100pN for 0.1sec
	middle = starts +  NumberByKey(" RampDownDuration", Info, "=")
	ends = middle +  NumberByKey(" RampUpDuration", Info, "=")	
	Duplicate/O/R=(starts, middle) $Forcewave, $smForce
	Wave force = $smForce
	force *= -1
	CurveFit/Q/N line $smForce(starts, middle) /D=$smForce
	Duplicate/O/R=(starts, middle) $LcWave, $Lccut
	DoWindow/K LcvsF
	Display/W=(0,470,550,650)
	DoWindow/C LcvsF
	AppendToGraph $Lccut vs $smForce
	ModifyGraph rgb($Lccut) = (0,52224,52224)
	
	smForce = ForceName + num2str (DisplayStart)	+ "_up_sm_Lc"
	Lccut = "Contour_Length" +  num2str(DisplayStart) + "_up_cut"
	Duplicate/O/R=(middle, ends)  $Forcewave, $smForce
	Wave force = $smForce
	force *= -1
	CurveFit/Q/N line $smForce(middle, ends) /D=$smForce
	Duplicate/O/R=(middle, ends) $LcWave, $Lccut
	AppendToGraph $Lccut vs $smForce
	ModifyGraph rgb($Lccut) = (52224,0,41728)
	Label bottom "Force (pN)"
	Label left "Contourlength Lc (nm)"
	SetAxis left 0,40
	ModifyGraph grid(left)=1
	ShowInfo
	SetDataFolder root:Data
End


Function BootStrapAverageWaves(ctrlName) : ButtonControl
	String ctrlName
	Variable NumWaves, m, i, k
	NVAR 	B			=	root:FC_Analysis:BootStrapNumIterations	//	Number of iterations
	NVAR  constrains = root:FC_Analysis:BootStrapConstrain		//	0: unconstrained ; 1: constrained
	SVAR WaveNamePrefix	= root:FC_Analysis:SumTraces:AvgTracePrefix		
	Variable MaxScale	=	0
	Variable MinScale	=	Inf
	Variable DeltaTime	=	Inf
	Variable N
	Variable ShortestWaveN = Inf
	Variable V_fitOptions=4	//	Turns the anoying Fiting window Off
	Variable CurveLenth //	in time
	String List
	String status = ""
	Variable StartTime=DateTime
	variable TimeLeft=0
	Variable MinutesLeft=0
	Variable SecondsLeft=0
	PauseUpdate

	List = WaveList(WaveNamePrefix+"*", ";", "")
	NumWaves = ItemsInList(List)
	If(NumWaves<3)
		Print NumWaves, "waves with prefix \'" ,WaveNamePrefix,"\' in current data folder ("+GetDataFolder(1) +")"
		beep
		Return 1
	EndIF

	Try	//	Catch and respond to abort conditions in user functions.
		Make/O/T/N=(NumWaves)	BootStrapSample
		Make/O/N=(B) BootStrap_shortest=NaN,BootStrap_wheighted=NaN,BootStrap_fillup=NaN
		Make/O/T/N=2 T_Constraints = {"K0 > -K1","K0 < -K1"}
		String WavesStatus =  Num2Str(NumWaves)+" waves in folder "+GetDataFolder(1)
		NewPanel/K=1 /N=StatusPanel /W=(100,100,400,300)
		TitleBox TBProgress,pos={25,50},size={111,20},title="BootStraping!",fSize=12,frame=0,fStyle=1, win=StatusPanel
		TitleBox TBWavesFound,pos={25,20},size={111,20},title=WavesStatus,fSize=12,frame=0,fStyle=0, win=StatusPanel
		Display/W=(10,100,290,180) /HOST=StatusPanel BootStrap_wheighted,BootStrap_shortest,BootStrap_fillup
		ModifyGraph rgb(BootStrap_wheighted)=(0,52224,0),rgb(BootStrap_fillup)=(0,12800,52224)
		ModifyGraph axOffset(left)=-3,axOffset(bottom)=-1,mode=2
		for (m = 0; m < B; m += 1)						// perform B bootstrapped samples
			for (i = 0; i < NumWaves; i += 1)			// pick N curves with replacement, add them and fit to get rate
				k = floor((enoise(NumWaves)+NumWaves)/2)	//generate random number from 0 to N-1
				BootStrapSample[i] = StringFromList(k,List)		
			endfor
			// now we have to add all waves in BootStrapSample
			for (i = 0; i < NumWaves; i += 1)			// go through all waves to determine max length
				Wave cut = $(BootStrapSample[i])		// get wave from list
				CurveLenth = pnt2x(cut,numpnts(cut)-1)
				if (CurveLenth > MaxScale)
					MaxScale =CurveLenth	// get the duration of the longest wave
				endif
				if (CurveLenth < MinScale)
					MinScale = CurveLenth	// get the duration of the shortes wave
				endif
				if (deltax(cut) < DeltaTime)
					DeltaTime = deltax(cut)			// get the smallest deltax of all waves
				endif
			endfor
			Variable NumberOfPoints = Round(MaxScale/DeltaTime)+1
			Make/O/N=(NumberOfPoints) BootSum=0,BootSumExt=0,BootSumCount=0
			SetScale/P x, 0, (DeltaTime), "s", BootSum,BootSumExt,BootSumCount
			for (i = 0; i < NumWaves; i += 1)	// go through all waves
				Wave cut = $(BootStrapSample[i])
				if(deltax(cut)==DeltaTime)
					N = numpnts(cut)
					Bootsum[0,N-1] += cut
					BootSumExt[0,N-1] += cut
				else
					N =Round(pnt2x(cut,numpnts(cut)-1)/DeltaTime)
					Interpolate2/N=(N)/Y=TempInterpolationWave cut
					Wave TempInterpolationWave
					Bootsum[0,N-1] += TempInterpolationWave
					BootsumExt[0,N-1] += TempInterpolationWave
				endif
				if(N<NumberOfPoints)
					BootSumExt[N,NumberOfPoints-1] += cut[N-1]
				endif
				BootSumCount[0,N-1] +=1
			endfor
			Bootsum /= BootSumCount	
			BootSumExt	/= NumWaves	
			//now fit exponential to sum to get rate
			IF(Constrains)
				Wave W_coef
//				CurveFit/N/Q exp BootsumExt(0,MinScale) /C=T_Constraints 
//				BootStrap_shortest[m]= W_coef[2]
//				CurveFit/N/Q exp Bootsum(0,MaxScale) /C=T_Constraints  /W=BootSumCount
//				BootStrap_wheighted[m]= W_coef[2]
//				CurveFit/NTHR=0/N/Q exp BootsumExt(0,MaxScale) /C=T_Constraints 
//				BootStrap_fillup[m]= W_coef[2]
				
				CurveFit/NTHR=0/N/Q exp BootsumExt /C=T_Constraints 
				BootStrap_fillup[m]= W_coef[2]
				BootStrap_shortest[m]= W_coef[2]
				BootStrap_wheighted[m]= W_coef[2]
			Else
			
				Wave W_coef
				CurveFit/N/Q/O exp BootsumExt(0,MaxScale)		//initial guess
				Variable amp=W_coef[0]
				Variable rate=W_coef[2]
				W_coef = {amp,rate}
				FuncFit/NTHR=0/Q/N surv W_coef  BootsumExt(0,MaxScale) /D 	//fit
				BootStrap_fillup[m]= W_coef[1]
				
				BootStrap_shortest[m]= W_coef[1]
				BootStrap_wheighted[m]= W_coef[1]

//				CurveFit/N/Q exp BootsumExt(0,MinScale) 
//				Wave W_coef
//				BootStrap_shortest[m]= W_coef[2]
//				CurveFit/N/Q exp Bootsum(0,40)  /W=BootSumCount
//				BootStrap_wheighted[m]= W_coef[2]
//				CurveFit/N/Q exp BootsumExt(0,40)
//				BootStrap_fillup[m]= W_coef[2]
			EndIF
			
			IF(PeriodicUpdate(2))
				TimeLeft=(DateTime-StartTime)/(m+1)*(B-m)
				MinutesLeft = floor(TimeLeft/60)
				SecondsLeft=Floor(TimeLeft-60*MinutesLeft)
				status = "BootStraping! "+ Num2Str(m)+"/"+Num2Str(B)+" = "+Num2Str(100*m/B)+"% \rRemaining time: "+Num2Str(MinutesLeft)+"m:"+Num2Str(SecondsLeft)+"s"
				TitleBox TBProgress , title = status,  win=StatusPanel
				DoUpdate
			EndIF
			DoWindow/K AverageTraceGraph
		endfor
		status = "Done!"
		TitleBox TBProgress , title = status,  win=StatusPanel
	
	catch
		DoWindow/K StatusPanel
	endtry
	
	Variable NumberOfBins = Max(B/5,5)
	Variable MinValue, MaxValue
	Make/N=(NumberOfBins)/D/O BootStrap_wheighted_Hist, BootStrap_shortest_Hist, BootStrap_fillup_hist

	WaveStats/M=2/Q BootStrap_shortest
	Variable BootStrap_shortest_SDev = V_sdev
	Variable BootStrap_shortest_Avg = V_avg
	MinValue = V_min
	maxValue = V_max

	WaveStats/M=2/Q BootStrap_wheighted
	Variable BootStrap_wheighted_SDev = V_sdev
	Variable BootStrap_wheighted_avg = V_avg
	MinValue = Min(V_min,MinValue)
	MaxValue = Max(V_Max,MaxValue)

	WaveStats/M=2/Q BootStrap_fillup
	Variable BootStrap_fillup_SDev = V_sdev
	Variable BootStrap_fillup_avg = V_avg
	MinValue = Min(V_min,MinValue)
	MaxValue = Max(V_Max,MaxValue)

	Histogram/B={MinValue,(MaxValue-MinValue)/NumberOfBins,NumberOfBins} BootStrap_shortest,BootStrap_shortest_Hist
	Histogram/B={MinValue,(MaxValue-MinValue)/NumberOfBins,NumberOfBins} BootStrap_wheighted,BootStrap_wheighted_Hist
	Histogram/B={MinValue,(MaxValue-MinValue)/NumberOfBins,NumberOfBins} BootStrap_fillup,BootStrap_fillup_hist

	DoWindow/K BootStrapValuesDistribution
	Display/K=1/N=BootStrapValuesDistribution BootStrap_wheighted_Hist, BootStrap_shortest_Hist, BootStrap_fillup_hist
	ModifyGraph rgb(BootStrap_wheighted_Hist)=(0,52224,0),rgb(BootStrap_fillup_hist)=(0,0,52224)
	Legend/N=BootStrapLegend/J/F=0/A=MC/X=26.97/Y=39.37 ""
	AppendText/N=BootStrapLegend/W=BootStrapValuesDistribution "\\s(BootStrap_shortest_Hist) Shortest\t: "+ Num2Str(BootStrap_shortest_Avg)+"±"+Num2Str(BootStrap_shortest_SDev)
	AppendText/N=BootStrapLegend/W=BootStrapValuesDistribution "\\s(BootStrap_wheighted_Hist) Weighted\t: "+ Num2Str(BootStrap_wheighted_Avg)+"±"+Num2Str(BootStrap_wheighted_SDev)
	AppendText/N=BootStrapLegend/W=BootStrapValuesDistribution "\\s(BootStrap_fillup_hist) FillUp\t: "+ Num2Str(BootStrap_fillup_Avg)+"±"+Num2Str(BootStrap_fillup_SDev)

		
	//	KillWaves/Z TempInterpolationWave,BootSum,BootSumExt,BootSumCount
	DoWindow/K StatusPanel
End


function offs()

	NVAR num=root:FC_Analysis:FCDisplayStartNumber
	
	Wave target=$("FC_Length" + num2str(num))
	
	Variable offset=mean(target, 0.0393, 0.0917)
	target-=offset

end


function saveFCmeasure(stepSize, stepForce, traceNo)
	Variable stepSize, stepForce, traceNo
	
	WAVE FCsteps = root:FC_Analysis:FCsteps
	Redimension/N=(numpnts(FCsteps)+1) FCsteps
	FCsteps[numpnts(FCsteps)-1] = abs(stepSize)
	
	WAVE FCforces = root:FC_Analysis:FCforces
	Redimension/N=(numpnts(FCforces)+1) FCforces
	FCforces[numpnts(FCforces)-1] = abs(stepForce)
	
	
		//save trace number
	WAVE FCstepsNo = root:FC_Analysis:FCstepsNo
	Redimension/N=(numpnts(FCstepsNo)+1) FCstepsNo
	FCstepsNo[numpnts(FCstepsNo)-1] = traceNo
end

function FC_ApplyFilter()
	NVAR DisplayStartNumber = root:FC_Analysis:FCDisplayStartNumber
	SVAR ForceName = root:FC_Analysis:ForceWaveName
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	
	SetDataFolder root:Data
	Duplicate/O $(LengthName + num2str(DisplayStartNumber)), filtered_L
	Duplicate/O $(ForceName + num2str(DisplayStartNumber)), filtered_F
	Make/O/D/N=0 coefs
	FilterFIR/DIM=0/LO={0.0299,0.0897,101}/COEF coefs, filtered_L
	FilterFIR/DIM=0/LO={0.0299,0.0897,101}/COEF coefs, filtered_F
	AppendToGraph filtered_L
	AppendToGraph/L=ForceAxis filtered_F
	ModifyGraph hideTrace($(LengthName + num2str(DisplayStartNumber)))=1,hideTrace($(ForceName + num2str(DisplayStartNumber)))=1;DelayUpdate
	ModifyGraph rgb(filtered_F)=(0,0,0)

end



//*******************************************************************************************************************************************************************
		//go through all traces between startT and endT and locate steps
Function FC_DetectStepsAll(startT, endT)
	variable startT, endT
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	make/o/n=0/t root:FC_Analysis:Steps:timestamps

	for(DisplayNo=startT; DisplayNo<(endT+1); DisplayNo+=1)
		Display_FC_Recordings()		//update display
		FC_DetectStepsFilt()
		sleep/S 0.2
	endfor
	
End

Function FC_DeleteStepsAll()
	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber

	for(DisplayNo=0; DisplayNo<363; DisplayNo+=1)
		Display_FC_Recordings()		//update display
		FC_DeleteAllSteps("")
	endfor
	
End

Function FC_DetectStepsFilt()  // Detect step times and size. 

	NVAR DisplayNo = root:FC_Analysis:FCDisplayStartNumber
	NVAR Noise = root:FC_Analysis:Steps:MinStep	// detect only steps that are larger than 5 nm
	NVAR Slide = root:FC_Analysis:Steps:SlideAverage
	NVAR Deviation = root:FC_Analysis:Steps:Deviation
	SVAR LengthName = root:FC_Analysis:LengthWaveName
	Variable Npoints, from, to, average
	String Length_Wave, Step_Wave, Step_WaveT
	
	//FC_ApplyFilter()
	
	SetDataFolder root:FC_Analysis:Steps
	Length_Wave = "root:Data:" + LengthName + num2str(DisplayNo)
	//Wave Length = root:data:filtered_L//$Length_Wave
	Wave Length = $Length_Wave
	//Length_Wave = "shift_" + LengthName + num2str(DisplayNo)
	Step_Wave = "StepStats_" + num2str(DisplayNo)
	Make/O/N=(1,4) $Step_Wave = 0
	Wave StepStats = $Step_Wave 
	SetDimLabel 1, 0, $("Time"), StepStats; SetDimLabel 1, 1, LengthBefore, StepStats
	SetDimLabel 1, 2, LengthAfter, StepStats; SetDimLabel 1, 3, StepSize, StepStats
	
	Step_WaveT = "StepStatsT_" + num2str(DisplayNo)
	Make/O/N=1/T $Step_WaveT
	Wave/T StepStatsT = $Step_WaveT 
	
	from = x2pnt(Length,8.2)//x2pnt(Length,0.152)//x2pnt(Length,hcsr(A))
	Npoints = x2pnt(Length,16.2)//x2pnt(Length,hcsr(B))
	
	StepStats[(DimSize(StepStats, 0)-1)][0] = pnt2x(Length, from)		// record where the detection started (will be important for unfolding times)
	to = from + 10//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate	
	do				// go through each point in wave until you get to the end
		do				// go through each plateau
			WaveStats/M=1/Q/R=[from, to] Length
			to += 3//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
			if (abs(Length[to] - V_avg) > Noise)
				break		// is a step is detected break out of loop
			endif
		while((to+3) < Npoints)
		do 					// since to is likely sitting on slope of step-, go back a bit to find foot of step
			if ( (Length[to] - Length[to-1] ) < 0)
				break
			endif
			to -= 1
		while (to > from)
		if (to - from > 50)
			WaveStats/M=2/Q/R=[to - 50, to] Length
		else
			WaveStats/M=2/Q/R=[from, to] Length
		endif
		
			//store timestamp
		Redimension/N=(numpnts(StepStatsT)+1) StepStatsT
		StepStatsT[numpnts(StepStatsT)-1]= StringByKey(" Time", note(Length), "=")
		
			//store new step as [xpos, ystart, yend, stepheight]
		Redimension/N=(DimSize(StepStats, 0)+1, 4) StepStats
		StepStats[(DimSize(StepStats, 0)-1)][0] = pnt2x(Length, to)
		StepStats[(DimSize(StepStats, 0)-1)][1] = V_avg	
		// now perform sliding average over 10 points to see when step ends
		from = to//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate
		to += slide*2//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
		WaveStats/M=1/Q/R=[from, to] Length
		average = V_avg
		do
			from += slide//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate	
			to += slide//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
			WaveStats/M=1/Q/R=[from, to] Length
			if ( abs (average - V_avg) < Deviation)	// if step levelled off
				StepStats[(DimSize(StepStats, 0)-1)][2] = V_avg
				StepStats[(DimSize(StepStats, 0)-1)][3] = V_avg - StepStats[(DimSize(StepStats, 0)-1)][1]
				from += slide//; Cursor/A=1/P/W=ForceClampAnalysis A $Length_Wave from; DoUpdate	
				to += 1//; Cursor/A=1/P/W=ForceClampAnalysis B $Length_Wave to; DoUpdate
				break
			elseif ((V_avg - StepStats[(DimSize(StepStats, 0)-1)][1]) > 500)	// if protein ruptured off
				StepStats[(DimSize(StepStats, 0)-1)][2] = V_avg
				StepStats[(DimSize(StepStats, 0)-1)][3] = V_avg - StepStats[(DimSize(StepStats, 0)-1)][1]
				FC_RedrawLines() 
				return 0
			endif
			average = V_avg
		while ((to+1) < Npoints)		
	while ((to+1) < Npoints)
	FC_RedrawLines() 
End
   
//*************************************************************  compile all stepheights and save timestamps ******************************************************************************************************
Function GetStepHeights()	// compile all stepheights
	String ctrlName	
	Variable NumWaves, i, Nsteps//, Binstart, Binwidth = 0.3, Numbins
	String List,ListT
	SetDataFolder root:FC_Analysis:Steps
	List = WaveList("StepStats_*", ";", "")
	ListT = WaveList("StepStatsT_*", ";", "")
	NumWaves = ItemsInList(List)
	if (NumWaves<0)
		DoAlert 0, "There are no StepStats waves!"
		SetDataFolder root:Data
		return 0
	endif

	Make/O/N=0 StepHeights	 			//step height
	Make/O/N=0/T StepHeights_T			//timestamp
	
	make/o/n=20 stepss=0
	make/o/n=20 steph=0
	setscale/p x,4.4,2.8,"",steph			//histogram scaling
	
	for (i = 0; i < NumWaves; i += 1)	
	
		Wave StepStats = $(StringFromList(i, List))		// get wave from list
		
			//generate histogram of stepsizes in current wave
		stepss=StepStats[p][3]
		histogram/b=2 stepss,steph
		
			//store steps if trace passes test (more than one )
		//if(wavemax(steph)>1)
			Nsteps = DimSize(StepStats, 0)-2				// exclude first and last entry
			Redimension/N=(numpnts(StepHeights)+Nsteps) StepHeights
			StepHeights[numpnts(StepHeights)-Nsteps, numpnts(StepHeights) - 1] = StepStats[p-(numpnts(StepHeights)-Nsteps)+1][3]
		
			Wave/T StepStatsT = $(StringFromList(i, ListT))	// get wave from list
			Nsteps = DimSize(StepStatsT, 0)-2				// exclude first and last entry
			Redimension/N=(numpnts(StepHeights_T)+Nsteps) StepHeights_T
			StepHeights_T[numpnts(StepHeights_T)-Nsteps, numpnts(StepHeights_T) - 1] = StepStatsT[p-(numpnts(StepHeights_T)-Nsteps)+1]
		//endif
		
	endfor

	SetDataFolder root:Data
End

function cleansteps()	//removes bad values

	SetDataFolder root:FC_Analysis:Steps
	make/o/n=0 clean_steps,clean_steps_T
	wave steps=StepHeights10GSSG
	wave steps_T=StepHeights10GSSG_T
	
	variable i, imax=numpnts(steps)
	variable j=0
	for(i=0;i<imax;i+=1)
		if(steps[i]>5)
			j+=1
			redimension/n=(j) clean_steps, clean_steps_T
			clean_steps[j-1]=steps[i]
			clean_steps_T[j-1]=steps_T[i]
		endif
	endfor

end

	//*************************************** Export with suffix ***************************************
	
Function add_suffix(suffix)
	String suffix
	
	String T_List=WaveList("cut_*",";","")
	
	Variable i = 0
	Variable numTraces = ItemsInList(T_List)
	
		//Loop through all Traces
	for(i=0;i<numTraces;i+=1)
		
			//Load Force wave
		String Trace_name=StringFromList(i,T_List)
		String new_Trace_name=Trace_name + suffix
		Duplicate $Trace_name $new_Trace_name
	endfor
	
End


Function surv(w,x) : FitFunc
	Wave w
	Variable x

	//CurveFitDialog/ These comments were created by the Curve Fitting dialog. Altering them will
	//CurveFitDialog/ make the function less convenient to work with in the Curve Fitting dialog.
	//CurveFitDialog/ Equation:
	//CurveFitDialog/ f(x) = A-A*exp(-k*x)
	//CurveFitDialog/ End of Equation
	//CurveFitDialog/ Independent Variables 1
	//CurveFitDialog/ x
	//CurveFitDialog/ Coefficients 2
	//CurveFitDialog/ w[0] = A
	//CurveFitDialog/ w[1] = k

	return w[0]-w[0]*exp(-w[1]*x)
End
