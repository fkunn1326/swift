// RUN: %empty-directory(%t)

/// First Test: Check `@_usableFromInline` is not added to types in PackageCMO mode.
// RUN: %target-swift-frontend -parse-as-library %s -O -wmo -cross-module-optimization -module-name=Lib -package-name pkg -emit-module -o %t/Lib-cmo.swiftmodule
// RUN: %target-sil-opt -module-name Lib -enable-sil-verify-all %t/Lib-cmo.swiftmodule -o %t/Lib-cmo.sil

// RUN: %target-swift-frontend -parse-as-library %s -O -wmo -enable-library-evolution -experimental-allow-non-resilient-access -experimental-package-cmo -module-name=Lib -package-name pkg -emit-module -o %t/Lib-package-cmo.swiftmodule
// RUN: %target-sil-opt -module-name Lib -enable-sil-verify-all %t/Lib-package-cmo.swiftmodule -o %t/Lib-package-cmo.sil

// RUN: %FileCheck %s --check-prefix=CHECK-CMO < %t/Lib-cmo.sil
// RUN: %FileCheck %s --check-prefix=CHECK-PACKAGE-CMO < %t/Lib-package-cmo.sil

/// Second Test: Check .swiftinterface files with and without PackageCMO have the same decl signatures without `@_usableFromInline`.
// RUN: %target-swift-frontend -emit-module %s -I %t \
// RUN:   -module-name Lib -package-name pkg \
// RUN:   -enable-library-evolution -swift-version 6 \
// RUN:   -emit-module-path %t/Lib.swiftmodule \
// RUN:   -emit-module-interface-path %t/Lib.swiftinterface \
// RUN:   -emit-private-module-interface-path %t/Lib.private.swiftinterface \
// RUN:   -emit-package-module-interface-path %t/Lib.package.swiftinterface
// RUN: %FileCheck %s --check-prefixes=CHECK-PKG-INTERFACE,CHECK-INTERFACE < %t/Lib.package.swiftinterface
// RUN: %FileCheck %s --check-prefix=CHECK-INTERFACE < %t/Lib.swiftinterface

// RUN: rm -rf %t/Lib.swiftinterface
// RUN: rm -rf %t/Lib.private.swiftinterface
// RUN: rm -rf %t/Lib.package.swiftinterface

// RUN: %target-swift-frontend -emit-module %s -I %t \
// RUN:   -module-name Lib -package-name pkg \
// RUN:   -enable-library-evolution -swift-version 6 \
// RUN:   -O -wmo \
// RUN:   -experimental-allow-non-resilient-access -experimental-package-cmo \
// RUN:   -emit-module-path %t/Lib.swiftmodule \
// RUN:   -emit-module-interface-path %t/Lib.swiftinterface \
// RUN:   -emit-private-module-interface-path %t/Lib.private.swiftinterface \
// RUN:   -emit-package-module-interface-path %t/Lib.package.swiftinterface
// RUN: %FileCheck %s --check-prefixes=CHECK-PKG-INTERFACE,CHECK-INTERFACE < %t/Lib.package.swiftinterface
// RUN: %FileCheck %s --check-prefix=CHECK-INTERFACE < %t/Lib.swiftinterface

// REQUIRES: swift_in_compiler

// CHECK-PACKAGE-CMO-NOT: @usableFromInline
// CHECK-PKG-INTERFACE-NOT: @usableFromInline
// CHECK-INTERFACE-NOT: @usableFromInline

// CHECK-PKG-INTERFACE: final package class PkgKlass {
// CHECK-PKG-INTERFACE: @inline(never) package func createKlass() -> Lib.PkgKlass
// CHECK-INTERFACE: @inline(never) public func classWithPublicProperty<T>(_ t: T) -> Swift.Int
// CHECK-INTERFACE: @inline(never) public func run()

// CHECK-CMO: @usableFromInline
// CHECK-CMO-NEXT: final class InternalKlass
final class InternalKlass {
  var myVar: Int = 11
  init() {}
}

final package class PkgKlass {
  var internalVar: InternalKlass = InternalKlass()
  package init() {}
}

@inline(never)
package func createKlass() -> PkgKlass {
  return PkgKlass()
}

// CHECK-CMO: sil [serialized] [noinline] [canonical] @$s3Lib23classWithPublicPropertyySixlF : $@convention(thin) <T> (@in_guaranteed T) -> Int {
@inline(never)
public func classWithPublicProperty<T>(_ t: T) -> Int {
  // CHECK-CMO: ref_element_addr {{.*}} : $InternalKlass, #InternalKlass.myVar
  return createKlass().internalVar.myVar
}

@inline(never)
public func run() {
  print(classWithPublicProperty(33))
}
