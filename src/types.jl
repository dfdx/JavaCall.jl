
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


type JavaClass
    classname::String
end



type JavaObject
    ptr::Ptr{Void}
    class::JavaClass
    
    function JavaObject(class::JavaClass)
        jo = new(ptr, class.classname)
        # finalizer(jo, deleteref)
        return jo
    end 
    
    # JavaObject(class, argtypes::Tuple, args...) = jnew(class, argtypes, args...)    
end


macro jimport(class)
    if isa(class, Expr)
        juliaclass=sprint(Base.show_unquoted, class)
    elseif  isa(class, Symbol)
        juliaclass=string(class)
    elseif isa(class, String) 
        juliaclass=class
    else 
        error("Macro parameter is of type $(typeof(class))!!")
    end
    quote 
        JavaObject{(Base.symbol($juliaclass))}
    end
    
end
