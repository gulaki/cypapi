from setuptools import setup, Extension
import os

def config_PAPI_PATH_var(ext: Extension):
    papi_path = os.environ.get('PAPI_PATH')
    if papi_path is None:
        return None
    papi_inc = os.path.join(papi_path, 'include')
    papi_lib = os.path.join(papi_path, 'lib')
    ext.include_dirs.append(papi_inc)
    ext.library_dirs.append(papi_lib)
    return papi_lib

def config_pkgconfig(ext: Extension):
    import pkgconfig
    try:
        pkgconfig.configure_extension(ext, 'papi')
    except pkgconfig.pkgconfig.PackageNotFoundError:
        return None
    papi_lib = pkgconfig.variables('papi')['libdir']
    return papi_lib

def config_LIBRARY_PATH(ext: Extension):
    lib_path = os.environ.get('LIBRARY_PATH')
    if lib_path is None:
        return None
    lib_paths = lib_path.split(':')
    for path in lib_paths:
        if any(['libpapi' in item for item in os.listdir(path)]):
            papi_lib = path
            return papi_lib


ext = Extension('cypapi', sources=['papi/cypapi.pyx'], libraries=['papi'])

papi_lib = config_PAPI_PATH_var(ext)

if not papi_lib:
    papi_lib = config_pkgconfig(ext)

if not papi_lib:
    papi_lib = config_LIBRARY_PATH(ext)

if os.name != 'nt' and papi_lib:
    ext.runtime_library_dirs.append(papi_lib)

setup(
    name = "cypapi",
    version = '0.1',
    description = 'Python interface for the PAPI performance monitoring library',
    author = 'Anustuv Pal',
    author_email = 'anustuv@gmail.com',
    ext_modules = ([ext]),
)
