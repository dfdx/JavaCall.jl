
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


################# JavaClass ####################

# JavaClass is used for importing, calling static methods and defining `jcall` types
# except for static methods, JavaClass should be considered as a TYPE

type JavaClass
    ptr::Ptr{Void}
    classname::String
end


@memoize function JavaClass(classname::String)
    jniname = utf8(replace(classname, '.', '/'))
    jclassptr = ccall(jnifunc.FindClass, Ptr{Void}, (Ptr{JNIEnv}, Ptr{Uint8}), penv, jniname)
    if jclassptr == C_NULL
        error("Class Not Found $jclass")
    end
    return JavaClass(jclassptr, classname)
end


################# JavaObject ####################

# JavaObject is used for instantiating Java objects and calling methods
# it should be considered as DATA

# type parameter T is used for dispatching and should be equal to `symbol(obj.class.classname)`

type JavaObject{T}
    ptr::Ptr{Void}
    class::JavaClass

    function JavaObject{T}(ptr::Ptr{Void}, class::JavaClass)
        jo = new(ptr, class)
        finalizer(jo, deleteref)
        return jo
    end
end


function JavaObject(classname::String)
    class = JavaClass(classname)
    jo = JavaObject{symbol(classname)}(ptr, class)
    finalizer(jo, deleteref)
    return jo
end

# JavaObject(class, argtypes::Tuple, args...) = jnew(class, argtypes, args...)


function deleteref(x::JavaObject)
    if x.ptr == C_NULL; return; end
    if (penv==C_NULL); return; end
    #ccall(:jl_,Void,(Any,),x)
    ccall(jnifunc.DeleteLocalRef, Void, (Ptr{JNIEnv}, Ptr{Void}), penv, x.ptr)
    x.ptr=C_NULL #Safety in case this function is called direcly, rather than at finalize
    return
end



################# core funcitions ####################


# jimport simply creates instance of JavaClass with specified class name
macro jimport(class)
    JavaClass(string(class))
end
