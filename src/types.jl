
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

if !isdefined(:JavaClass) # avoiding error in REPL

    # note that classname is not a type parameter, but instead simple field
    # the idea is to mimic JVM that doesn't know about object's type during runtime
    # this way we also avoid Julia's type dispatching for different Java classes
    # and treat them all the same way
    type JavaClass    
        ptr::Ptr{Void} 
        classname::String
        typeparams::Vector{JavaClass}  # NOTE: not used yet
    end
    
end

@memoize function JavaClass(classname::String)
    jniname = utf8(replace(classname, '.', '/'))
    jclassptr = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, jniname)
    if jclassptr == C_NULL
        error("Class Not Found $jclass")
    end
    return JavaClass(jclassptr, classname, [])
end


################# JavaObject ####################

type JavaObject
    ptr::Ptr{Void}
    class::JavaClass    
end

function deleteref(x::JavaObject)	
	if x.ptr == C_NULL; return; end
	if (penv==C_NULL); return; end
	#ccall(:jl_,Void,(Any,),x)
	ccall(jnifunc.DeleteLocalRef, Void, (Ptr{JNIEnv}, Ptr{Void}), penv, x.ptr)
	x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize 
	return
end 


function JavaObject(class::JavaClass)
    jo = new(ptr, class.classname)
    finalizer(jo, deleteref)
    return jo
end 
    
# JavaObject(class, argtypes::Tuple, args...) = jnew(class, argtypes, args...)    


################# core funcitions ####################


# jimport simply creates instance of JavaClass with specified class name
macro jimport(class)
    JavaClass(string(class)) 
end

