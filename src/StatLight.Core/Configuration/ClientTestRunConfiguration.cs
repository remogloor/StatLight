﻿using System;
using System.Runtime.Serialization;
using StatLight.Core.UnitTestProviders;
using System.Collections.Generic;
using System.Reflection;

namespace StatLight.Core.Configuration
{
    [DataContract]
    public class ClientTestRunConfiguration
    {
        private string _tagFilters = string.Empty;
        private List<string> _methodsToTest;

        public ClientTestRunConfiguration(UnitTestProviderType unitTestProviderType, List<string> methodsToTest, string tagFilters)
        {
            if (methodsToTest == null) throw new ArgumentNullException("methodsToTest");
            if (unitTestProviderType == UnitTestProviderType.Undefined)
                throw new ArgumentException("Must be defined", "unitTestProviderType");

            _methodsToTest = methodsToTest;
            _tagFilters = tagFilters ?? string.Empty;
            UnitTestProviderType = unitTestProviderType;
        }

        [DataMember]
        public string TagFilter
        {
            get
            {
                return _tagFilters;
            }
            set
            {
                if (value == null)
                    _tagFilters = string.Empty;
                else
                    _tagFilters = value;
            }
        }

        [DataMember]
        public UnitTestProviderType UnitTestProviderType { get; set; }

        [DataMember]
        public List<string> MethodsToTest
        {
            get { return (_methodsToTest ?? (_methodsToTest = new List<string>())); }
            set { _methodsToTest = value; }
        }

        private static ClientTestRunConfiguration _currentClientTestRunConfiguration;
        public static ClientTestRunConfiguration CurrentClientTestRunConfiguration
        {
            get { return _currentClientTestRunConfiguration; }
            set
            {
                _currentClientTestRunConfiguration = value;

#if SILVERLIGHT
                var expectedTestsToFindAndRunMessage = string.Join(
                    " *** Method Filter: {0}".FormatWith(Environment.NewLine),
                            _currentClientTestRunConfiguration.MethodsToTest.ToArray());
                StatLight.Client.Harness.Server.Debug(expectedTestsToFindAndRunMessage);
#endif

            }
        }

        public static bool ContainsMethod(MethodInfo methodInfo)
        {
            if (CurrentClientTestRunConfiguration == null)
                return false;
            if (methodInfo == null)
                throw new ArgumentNullException("methodInfo");

            if (CurrentClientTestRunConfiguration.MethodsToTest.Count == 0)
                return true;

            string methodString = methodInfo.DeclaringType.FullName + "." + methodInfo.Name;

            var containsMethod = CurrentClientTestRunConfiguration.MethodsToTest.Contains(methodString);

#if SILVERLIGHT
            var expectedTestsToFindAndRunMessage = " *** Contains Method: {0}, {1}".FormatWith(containsMethod, methodString);
            StatLight.Client.Harness.Server.Debug(expectedTestsToFindAndRunMessage);
#endif

            return containsMethod;
        }
    }
}
