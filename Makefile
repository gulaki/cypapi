build: setup.py papi/cypapi.pyx papi/papih.pxd
	python setup.py build_ext --inplace

install:
	pip install .

clean:
	rm -rf *.so build/ *.egg-info/
	make -C papi clean