all: test_parallel

test_parallel:
	vivado -mode batch -source create_prj_test1.tcl
	cd export_sim/xsim && bash packet_gen_parallel.sh

test_shaaes:
	vivado -mode batch -source create_prj_test2.tcl
	cd export_sim/xsim && bash packet_gen_shaaes.sh

clean: 
	-rm -rf export_sim frenzy_build *.log *.jou *.cache *.pb


