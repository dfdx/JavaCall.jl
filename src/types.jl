
################# primitive types ####################

# jni_md.h
typealias jint Cint
#ifdef _LP64 /* 64-bit Solaris */
# typedef long jlong;
typealias jlong Clonglong
typealias jbyte Cchar
 
# jni.h

typealias jboolean Cuchar
typealias jchar Cushort
typealias jshort Cshort
typealias jfloat Cfloat
typealias jdouble Cdouble
typealias jsize jint
jprimitive = Union(jboolean, jchar, jshort, jfloat, jdouble, jint, jlong)


################# JavaClass (for importing) ####################

type JavaClass
    # TOOD: add optional type parameters
    ptr::Ptr{Void} 
    classname::String
end

function JavaClass(classname::String)
    
end


################# JavaObject ####################

type JavaObject
    ptr::Ptr{Void}
    class::JavaClass    
end

function JavaObject(class::JavaClass)
    jo = new(ptr, class.classname)
    # finalizer(jo, deleteref)
    return jo
end 
    
# JavaObject(class, argtypes::Tuple, args...) = jnew(class, argtypes, args...)    


################# core funcitions ####################


# jimport simply creates instance of JavaClass with specified class name
macro jimport(class)
    JavaClass(string(class)) 
end
